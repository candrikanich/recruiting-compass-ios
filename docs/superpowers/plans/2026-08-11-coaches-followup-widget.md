# Coaches Needing Follow-up Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a web-parity "Coaches Needing Follow-up" widget to the iOS dashboard, listing coaches not contacted in 14+ days (or never), with Email / Text / View Profile actions.

**Architecture:** All follow-up logic (staleness filter, sort order, days-since label) lives in a pure `CoachFollowup` enum so it is fully unit-testable without simulator/UI. `DashboardViewModel` fetches schools → coaches (existing `DashboardManaging` methods) and stores the filtered list. A new SwiftUI widget renders it inside the existing `DashboardChartsAndDataSection`, gated by the already-present `coachFollowupWidget` visibility flag. Email/Text reuse the existing `QuickCommunicationView` (in-app compose + auto interaction logging); View Profile / View-all reuse `CoachDetailView` / `CoachesListView` via sheets.

**Tech Stack:** Swift 6, SwiftUI, `@Observable @MainActor` view models, Supabase (via existing services), XCTest.

## Global Constraints

- Source path is double-nested: `TheRecruitingCompass/TheRecruitingCompass/...`; tests: `TheRecruitingCompass/TheRecruitingCompassTests/...`. All `xcodebuild` runs from `TheRecruitingCompass/` (the `.xcodeproj` wrapper dir).
- New `.swift` files are auto-included (`PBXFileSystemSynchronizedRootGroup`). NEVER edit `.xcodeproj` or run `add_files_to_xcode.rb`.
- Follow-up threshold = **14 days** (web parity). Divergence from `CoachAnalytics.needFollowUpCount` (30 days) is accepted and intentional.
- Boundary rule: a coach is stale iff `lastContactDateParsed == nil` OR `lastContactDateParsed < now - 14 days`. Exactly-14-days-ago is NOT stale.
- Use semantic fonts (`.headline`, `.caption`), `Color.Surface.card`, `.brandShadowSm()`. No `.system(size:)`. Interactive elements ≥44×44pt with `.accessibilityLabel`. Localize user-facing copy via `String(localized:)`. SwiftLint line length ≤120.
- Any new `@MainActor` class needs `nonisolated deinit {}`. (This plan adds none — widget/row are value-type `View`s.)
- Build: `xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'`. Trust xcodebuild's exit code, not a grep for "SUCCEEDED".

---

## File Structure

- Create `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/CoachFollowup.swift` — pure staleness/sort/label logic.
- Create `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/CoachFollowupTests.swift` — unit tests for the above.
- Create `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/CoachFollowupRow.swift` — one coach row + action buttons.
- Create `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/CoachFollowupWidget.swift` — card, count badge, empty state, sheets.
- Modify `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift` — add `coachesNeedingFollowup`, `allSchools`, `fetchCoachesFollowup()`, wire into fan-out.
- Modify `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/DashboardChartsAndDataSection.swift` — new params + render gate.
- Modify `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift:97-106` — pass new args.
- Modify `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/DashboardCustomizationView.swift` — add toggle row.

Reused as-is (no edits): `Coach` (`Features/Dashboard/Models/Coach.swift`), `School` (`Features/Dashboard/Models/School.swift`), `DashboardManaging.fetchSchools(familyUnitId:)` / `fetchCoaches(schoolIds:)`, `EntityNameLookup` (`Shared/Utilities/EntityNameLookup.swift`), `QuickCommunicationView` + `QuickCommunicationContext` (`Features/Coaches/...`), `CoachDetailView(coachId:allCoaches:allSchools:)`, `CoachesListView()`, `WidgetVisibility.coachFollowupWidget` (already exists, default `true`).

---

## Task 1: `CoachFollowup` pure logic + tests

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/CoachFollowup.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/CoachFollowupTests.swift`

**Interfaces:**
- Consumes: `Coach` (`.lastContactDateParsed: Date?`, `.fullName`).
- Produces:
  - `CoachFollowup.defaultThresholdDays: Int` (= 14)
  - `CoachFollowup.needsFollowup(_ coach: Coach, asOf now: Date, thresholdDays: Int = defaultThresholdDays) -> Bool`
  - `CoachFollowup.stale(_ coaches: [Coach], asOf now: Date, thresholdDays: Int = defaultThresholdDays) -> [Coach]` (filtered + sorted oldest-first, never-contacted first)
  - `CoachFollowup.daysSinceLabel(_ coach: Coach, asOf now: Date) -> String`

- [ ] **Step 1: Write the failing tests**

Create `TheRecruitingCompassTests/Features/Dashboard/CoachFollowupTests.swift`:

```swift
import XCTest
@testable import TheRecruitingCompass

final class CoachFollowupTests: XCTestCase {

  /// 2026-01-15 12:00:00 UTC — fixed "now" so tests are deterministic.
  private let now = Date(timeIntervalSince1970: 1_768_478_400)

  private func coach(id: String, lastContact: String?) -> Coach {
    Coach(
      id: id, firstName: "C\(id)", lastName: "L",
      schoolId: "s1", lastContactDate: lastContact,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  /// ISO string `days` before `now`.
  private func iso(daysAgo days: Int) -> String {
    let d = Calendar.current.date(byAdding: .day, value: -days, to: now)!
    let f = ISO8601DateFormatter()
    return f.string(from: d)
  }

  func testNeverContactedNeedsFollowup() {
    XCTAssertTrue(CoachFollowup.needsFollowup(coach(id: "1", lastContact: nil), asOf: now))
  }

  func testThirteenDaysAgoIsNotStale() {
    XCTAssertFalse(CoachFollowup.needsFollowup(coach(id: "1", lastContact: iso(daysAgo: 13)), asOf: now))
  }

  func testFourteenDaysAgoIsNotStale() {
    // Boundary: exactly 14 days ago is NOT stale (strictly older than cutoff required).
    XCTAssertFalse(CoachFollowup.needsFollowup(coach(id: "1", lastContact: iso(daysAgo: 14)), asOf: now))
  }

  func testFifteenDaysAgoIsStale() {
    XCTAssertTrue(CoachFollowup.needsFollowup(coach(id: "1", lastContact: iso(daysAgo: 15)), asOf: now))
  }

  func testStaleFiltersAndSortsNeverFirstThenOldest() {
    let recent = coach(id: "recent", lastContact: iso(daysAgo: 2))   // excluded
    let never = coach(id: "never", lastContact: nil)                 // included, first
    let old20 = coach(id: "old20", lastContact: iso(daysAgo: 20))    // included
    let old40 = coach(id: "old40", lastContact: iso(daysAgo: 40))    // included, oldest

    let result = CoachFollowup.stale([recent, never, old20, old40], asOf: now)

    XCTAssertEqual(result.map(\.id), ["never", "old40", "old20"])
  }

  func testDaysSinceLabelNever() {
    XCTAssertEqual(CoachFollowup.daysSinceLabel(coach(id: "1", lastContact: nil), asOf: now),
                   String(localized: "Never contacted"))
  }

  func testDaysSinceLabelPlural() {
    XCTAssertEqual(CoachFollowup.daysSinceLabel(coach(id: "1", lastContact: iso(daysAgo: 20)), asOf: now),
                   String(localized: "20 days ago"))
  }

  func testDaysSinceLabelSingular() {
    XCTAssertEqual(CoachFollowup.daysSinceLabel(coach(id: "1", lastContact: iso(daysAgo: 1)), asOf: now),
                   String(localized: "1 day ago"))
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/CoachFollowupTests
```
Expected: FAIL — `Cannot find 'CoachFollowup' in scope`.

- [ ] **Step 3: Write the minimal implementation**

Create `Features/Dashboard/Models/CoachFollowup.swift`:

```swift
import Foundation

/// Pure follow-up logic for the dashboard "Coaches Needing Follow-up" widget.
/// Web parity: a coach needs follow-up when never contacted, or last contacted
/// more than `defaultThresholdDays` (14) ago. Kept side-effect free for testing.
enum CoachFollowup {
  static let defaultThresholdDays = 14

  static func needsFollowup(
    _ coach: Coach, asOf now: Date, thresholdDays: Int = defaultThresholdDays
  ) -> Bool {
    guard let last = coach.lastContactDateParsed else { return true }
    guard let cutoff = Calendar.current.date(byAdding: .day, value: -thresholdDays, to: now)
    else { return true }
    return last < cutoff
  }

  /// Coaches needing follow-up, sorted never-contacted first then oldest contact first.
  static func stale(
    _ coaches: [Coach], asOf now: Date, thresholdDays: Int = defaultThresholdDays
  ) -> [Coach] {
    coaches
      .filter { needsFollowup($0, asOf: now, thresholdDays: thresholdDays) }
      .sorted { a, b in
        switch (a.lastContactDateParsed, b.lastContactDateParsed) {
        case (nil, nil): return false
        case (nil, _): return true
        case (_, nil): return false
        case let (x?, y?): return x < y
        }
      }
  }

  static func daysSinceLabel(_ coach: Coach, asOf now: Date) -> String {
    guard let last = coach.lastContactDateParsed else {
      return String(localized: "Never contacted")
    }
    let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
    switch days {
    case ..<1: return String(localized: "Today")
    case 1: return String(localized: "1 day ago")
    default: return String(localized: "\(days) days ago")
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/CoachFollowupTests
```
Expected: PASS (all 9 tests). Trust the exit code (0) + the passed count.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/CoachFollowup.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/CoachFollowupTests.swift
git commit -m "feat(dashboard): add CoachFollowup pure logic for follow-up widget

Claude-Session: https://claude.ai/code/session_01DfKUc46SNbxeivGzfasoSd"
```

---

## Task 2: DashboardViewModel data wiring

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift`

**Interfaces:**
- Consumes: `CoachFollowup.stale(_:asOf:)` (Task 1); `dashboardService.fetchSchools(familyUnitId:)`, `dashboardService.fetchCoaches(schoolIds:)`; `familyManager.familyUnitId`.
- Produces (read by Task 4 wiring): `DashboardViewModel.coachesNeedingFollowup: [Coach]`, `DashboardViewModel.allSchools: [School]`, `func fetchCoachesFollowup() async`.

- [ ] **Step 1: Add stored properties**

In `DashboardViewModel.swift`, after `var events: [FullEvent] = []` (currently line 21) add:

```swift
  var coachesNeedingFollowup: [Coach] = []
  var allSchools: [School] = []
```

- [ ] **Step 2: Add the fetch method**

After `fetchEvents()` (currently ends line 315) add:

```swift
  func fetchCoachesFollowup() async {
    guard let familyUnitId = familyManager.familyUnitId else {
      coachesNeedingFollowup = []
      allSchools = []
      return
    }
    do {
      let schools = try await dashboardService.fetchSchools(familyUnitId: familyUnitId)
      allSchools = schools
      let schoolIds = schools.map(\.id)
      guard !schoolIds.isEmpty else {
        coachesNeedingFollowup = []
        return
      }
      let coaches = try await dashboardService.fetchCoaches(schoolIds: schoolIds)
      coachesNeedingFollowup = CoachFollowup.stale(coaches, asOf: Date.now)
    } catch {
      logger.warning("Failed to load coaches follow-up: \(error.localizedDescription)")
    }
  }
```

- [ ] **Step 3: Wire into the main fan-out**

In `fetchDashboardData()`, in the `do` block, extend the concurrent group (currently lines 177-182):

```swift
      loadQuickTasks()
      async let visibilityTask: () = fetchWidgetVisibility()
      async let suggestionsTask: () = fetchSuggestions()
      async let eventsTask: () = fetchEvents()
      async let metricsTask: () = fetchMetrics()
      async let trendsTask: () = fetchInteractionTrends()
      async let coachesTask: () = fetchCoachesFollowup()
      _ = await (visibilityTask, suggestionsTask, eventsTask, metricsTask, trendsTask, coachesTask)
```

(Leave the no-family early-return branch at lines 152-157 unchanged — no `familyUnitId` there, so the list stays empty by design.)

- [ ] **Step 4: Build to verify it compiles**

Run:
```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: exit 0, no new errors. (No unit test here — the filter/sort logic is fully covered by Task 1; this task is pure orchestration verified by the compiler. The old `_ = await (...)` tuple must now have 6 elements.)

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/ViewModels/DashboardViewModel.swift
git commit -m "feat(dashboard): fetch coaches needing follow-up in DashboardViewModel

Claude-Session: https://claude.ai/code/session_01DfKUc46SNbxeivGzfasoSd"
```

---

## Task 3: Widget + row views

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/CoachFollowupRow.swift`
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/CoachFollowupWidget.swift`

**Interfaces:**
- Consumes: `Coach`, `School`, `CoachFollowup.daysSinceLabel(_:asOf:)`, `EntityNameLookup.schoolNameMap(from:)` + `schoolName(for:in:)`, `QuickCommunicationView(context:)`, `QuickCommunicationContext(coach:schoolName:)`, `CoachDetailView(coachId:allCoaches:allSchools:)`, `CoachesListView()`.
- Produces: `CoachFollowupWidget(coaches: [Coach], schools: [School])`, `CoachFollowupRow(coach:schoolName:onEmail:onText:onProfile:)`.

- [ ] **Step 1: Create the row**

Create `Features/Dashboard/Components/CoachFollowupRow.swift`:

```swift
import SwiftUI

struct CoachFollowupRow: View {
  let coach: Coach
  let schoolName: String
  let onEmail: () -> Void
  let onText: () -> Void
  let onProfile: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button(action: onProfile) {
        VStack(alignment: .leading, spacing: 2) {
          Text(coach.fullName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.primaryText)
          Text(schoolName)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
          Text(CoachFollowup.daysSinceLabel(coach, asOf: Date.now))
            .font(.caption2)
            .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "View \(coach.fullName) profile"))

      HStack(spacing: 12) {
        if coach.email != nil {
          Button(action: onEmail) {
            Label(String(localized: "Email"), systemImage: "envelope")
              .font(.caption)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Email \(coach.fullName)"))
        }
        if coach.phone != nil {
          Button(action: onText) {
            Label(String(localized: "Text"), systemImage: "message")
              .font(.caption)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Text \(coach.fullName)"))
        }
        Spacer()
      }
    }
    .padding(.vertical, 4)
  }
}
```

- [ ] **Step 2: Create the widget**

Create `Features/Dashboard/Components/CoachFollowupWidget.swift`:

```swift
import SwiftUI

struct CoachFollowupWidget: View {
  let coaches: [Coach]
  let schools: [School]

  @State private var isShowingAll = false
  @State private var quickCommContext: QuickCommunicationContext?
  @State private var profileCoachId: String?
  @State private var isShowingAllCoaches = false

  private var schoolNameMap: [String: String] { EntityNameLookup.schoolNameMap(from: schools) }
  private var visibleCoaches: [Coach] { isShowingAll ? coaches : Array(coaches.prefix(5)) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Coaches Needing Follow-up")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Spacer()
        if !coaches.isEmpty {
          Text("\(coaches.count)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.accentBlue.opacity(0.15))
            .clipShape(Capsule())
        }
      }

      Divider()

      if coaches.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
          Text("🎉 All caught up!")
            .font(.subheadline.weight(.semibold))
          Text("No coaches need immediate follow-up")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(.vertical)
      } else {
        VStack(spacing: 8) {
          ForEach(visibleCoaches) { coach in
            CoachFollowupRow(
              coach: coach,
              schoolName: EntityNameLookup.schoolName(for: coach.schoolId, in: schoolNameMap),
              onEmail: { presentQuickComm(coach) },
              onText: { presentQuickComm(coach) },
              onProfile: { profileCoachId = coach.id }
            )
            if coach.id != visibleCoaches.last?.id { Divider() }
          }
        }

        if coaches.count > 5 {
          Button {
            isShowingAllCoaches = true
          } label: {
            Text("View all \(coaches.count) coaches")
              .font(.caption)
              .foregroundStyle(Color.accentBlue)
          }
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .sheet(item: $quickCommContext) { context in
      QuickCommunicationView(context: context)
    }
    .sheet(item: Binding(
      get: { profileCoachId.map { CoachProfileRoute(id: $0) } },
      set: { profileCoachId = $0?.id }
    )) { route in
      CoachDetailView(coachId: route.id, allCoaches: coaches, allSchools: schools)
    }
    .sheet(isPresented: $isShowingAllCoaches) {
      CoachesListView()
    }
  }

  private func presentQuickComm(_ coach: Coach) {
    quickCommContext = QuickCommunicationContext(
      coach: coach,
      schoolName: EntityNameLookup.schoolName(for: coach.schoolId, in: schoolNameMap)
    )
  }
}

/// Identifiable wrapper so a coach id can drive `.sheet(item:)`.
private struct CoachProfileRoute: Identifiable {
  let id: String
}

#Preview {
  ScrollView {
    CoachFollowupWidget(
      coaches: [
        Coach(id: "1", firstName: "Pat", lastName: "Rivera", email: "pat@u.edu",
              phone: "5551234567", schoolId: "s1", lastContactDate: nil,
              createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"),
        Coach(id: "2", firstName: "Sam", lastName: "Lee", email: nil, phone: nil,
              schoolId: "s2", lastContactDate: "2026-01-01T00:00:00Z",
              createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z")
      ],
      schools: []
    )
    .padding()
  }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: exit 0. If `Color.accentBlue`, `Color.primaryText`, `Color.secondaryText`, or `Color.Surface.card` don't resolve, confirm the exact token names from `UpcomingEventsWidget.swift` (it uses `Color.secondaryText`, `Color.accentBlue`, `Color.Surface.card`) and match them.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/CoachFollowupRow.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/CoachFollowupWidget.swift
git commit -m "feat(dashboard): add CoachFollowupWidget and row views

Claude-Session: https://claude.ai/code/session_01DfKUc46SNbxeivGzfasoSd"
```

---

## Task 4: Render wiring + settings toggle

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/DashboardChartsAndDataSection.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift` (lines 97-106)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/DashboardCustomizationView.swift`

**Interfaces:**
- Consumes: `DashboardViewModel.coachesNeedingFollowup`, `.allSchools` (Task 2); `CoachFollowupWidget(coaches:schools:)` (Task 3); existing `WidgetVisibility.coachFollowupWidget`.

- [ ] **Step 1: Add params + render gate to the section**

In `DashboardChartsAndDataSection.swift`, add two stored props after `let events: [FullEvent]` (line 8):

```swift
  let coachesNeedingFollowup: [Coach]
  let allSchools: [School]
```

Then in `body`, immediately after the `UpcomingEventsWidget` block (lines 21-23) add:

```swift
      if visibility.coachFollowupWidget && !coachesNeedingFollowup.isEmpty {
        CoachFollowupWidget(coaches: coachesNeedingFollowup, schools: allSchools)
      }
```

Update the `#Preview` at the bottom to pass `coachesNeedingFollowup: []`, `allSchools: []`.

- [ ] **Step 2: Pass args from DashboardView**

In `DashboardView.swift`, in the `DashboardChartsAndDataSection(...)` call (lines 97-106), add after `events: viewModel.events,`:

```swift
                coachesNeedingFollowup: viewModel.coachesNeedingFollowup,
                allSchools: viewModel.allSchools,
```

- [ ] **Step 3: Add the settings toggle**

In `DashboardCustomizationView.swift`, after the "Events Summary" `ToggleCard` block (ends ~line 130) add:

```swift
          ToggleCard(
            icon: "person.2.badge.gearshape",
            label: String(localized: "Coaches Follow-up"),
            isOn: $viewModel.visibility.widgets.coachFollowupWidget,
            onChange: { viewModel.markChanged() }
          )
```

- [ ] **Step 4: Build to verify it compiles**

Run:
```bash
cd TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: exit 0, no new errors.

- [ ] **Step 5: Run the full follow-up test class as a regression gate**

Run:
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/CoachFollowupTests
```
Expected: PASS (9 tests).

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/DashboardChartsAndDataSection.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Views/DashboardView.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Preferences/Views/DashboardCustomizationView.swift
git commit -m "feat(dashboard): render CoachFollowupWidget + add visibility toggle

Claude-Session: https://claude.ai/code/session_01DfKUc46SNbxeivGzfasoSd"
```

---

## Manual verification (after Task 4)

- Launch app on a signed-in account with at least one school + a coach whose `last_contact_date` is null or 15+ days old → widget appears in the dashboard scroll below Upcoming Events, showing that coach with a days-since label.
- Tap coach name → `CoachDetailView` sheet. Tap Email/Text → `QuickCommunicationView` composer. With >5 stale coaches, "View all N coaches" opens `CoachesListView`.
- Toggle "Coaches Follow-up" off in Dashboard customization → widget disappears.
- Account with all coaches contacted <14 days → "🎉 All caught up!" (only when the flag is on AND the list is empty the whole card is hidden per the section gate; the empty-state copy shows only when the widget is rendered with an empty `coaches` array — see note below).

> **Note on empty state:** the section gate `!coachesNeedingFollowup.isEmpty` means the card is hidden when there are zero stale coaches. The widget's built-in "All caught up!" state therefore only shows if you choose to render it with an empty array (e.g. previews). This matches the existing `UpcomingEventsWidget` pattern (hidden when empty). If product wants the "All caught up!" card visible on the dashboard, drop `&& !coachesNeedingFollowup.isEmpty` from the Task 4 Step 1 gate — left as-is for parity with sibling widgets.

---

## Self-Review

- **Spec coverage:** data fetch (Task 2), 14-day pure logic + boundary (Task 1), widget/row/actions/empty state/count/view-all (Task 3), placement after events + existing `coachFollowupWidget` flag + settings toggle (Task 4), Email/Text via `QuickCommunicationView`, View Profile via `CoachDetailView` sheet — all covered. Divergence-from-30-day note recorded in Global Constraints.
- **Open question resolved:** "View all" → sheet-wraps `CoachesListView()` (Task 3).
- **Placeholder scan:** none — all steps carry real code.
- **Type consistency:** `CoachFollowup.stale`/`needsFollowup`/`daysSinceLabel`, `coachesNeedingFollowup`, `allSchools`, `CoachFollowupWidget(coaches:schools:)`, `CoachFollowupRow(coach:schoolName:onEmail:onText:onProfile:)` used identically across tasks. `WidgetVisibility.coachFollowupWidget` matches the existing model field (verified in `WidgetVisibility.swift:19`).
- **Deferred (not gaps):** no `DashboardViewModel` integration test — would require a 13-method `DashboardManaging` mock + `FamilyManager` stub with no existing harness; the filter/sort/label logic (the only real logic) is fully unit-tested in Task 1, and VM orchestration is compiler- + manually-verified. Revisit if a dashboard mock harness is later added.
