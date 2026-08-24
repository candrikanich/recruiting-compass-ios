# iOS Timeline Guidance Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Tasks | Guidance` segmented control to the iOS Recruiting Timeline and port the web guidance sidebar's 5 panels to iOS at parity.

**Architecture:** `RecruitingTimelineView` gains a segmented picker; the existing task content becomes the Tasks tab, and a new `TimelineGuidanceView` (5 collapsible widgets) becomes the Guidance tab. Two panels are new byte-for-byte ports of web static copy; two reuse/extract existing iOS calendar logic; one keeps the top-5 of an endpoint the VM already calls.

**Tech Stack:** Swift, SwiftUI, `@Observable @MainActor` MVVM, XCTest, `Localizable.xcstrings`.

**Spec:** `planning/2026-08-24-ios-timeline-guidance-parity-design.md`

## Global Constraints

- Source root (double-nested): `TheRecruitingCompass/TheRecruitingCompass/`; tests: `TheRecruitingCompass/TheRecruitingCompassTests/`.
- Build gate: `cd TheRecruitingCompass && xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'` — exit 0, no new errors, before any "done".
- All ViewModels `@MainActor`; every new `@MainActor` class needs `nonisolated deinit {}` (test-teardown double-free workaround).
- New `.swift` files auto-included (PBXFileSystemSynchronizedRootGroup) — NEVER edit `.xcodeproj`.
- SwiftLint line length ≤ 120.
- Static guidance copy = **byte-for-byte** from web source files; no paraphrase. Parity is the whole point.
- All new user-facing strings → `Core/Localizable.xcstrings`. Emoji icons stay literal.
- Phase words `freshman/sophomore/junior/senior` map 1:1 to `TimelinePhase` rawValues. `committed` → filter as `senior` for panels 4/5.

---

### Task 1: `ParentWorry` model + static dataset (port)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Models/ParentWorry.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Timeline/ParentWorryTests.swift`
- Port source (read verbatim): `recruiting-compass-web/utils/parentWorries.ts`

**Interfaces:**
- Produces: `struct ParentWorry: Identifiable { let id: String; let question: String; let answer: String; let phases: [TimelinePhase]; let category: WorryCategory }`; `enum WorryCategory: String { case academics, mental_health, recruiting, timeline }`; `static func ParentWorry.forPhase(_ phase: TimelinePhase) -> [ParentWorry]` (filter by `phases.contains`, sort by `category.rawValue` ascending — matches web `category.localeCompare`); `static let all: [ParentWorry]` (15 entries).

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TheRecruitingCompass

final class ParentWorryTests: XCTestCase {
    func testDatasetHasFifteenEntries() {
        XCTAssertEqual(ParentWorry.all.count, 15)
    }

    func testAllPhasesNonEmpty() {
        for worry in ParentWorry.all {
            XCTAssertFalse(worry.phases.isEmpty, "\(worry.id) has no phases")
        }
    }

    func testForPhaseFiltersByPhase() {
        let junior = ParentWorry.forPhase(.junior)
        XCTAssertFalse(junior.isEmpty)
        XCTAssertTrue(junior.allSatisfy { $0.phases.contains(.junior) })
    }

    func testForPhaseSortedByCategoryAlphabetical() {
        let sorted = ParentWorry.forPhase(.senior)
        let cats = sorted.map { $0.category.rawValue }
        XCTAssertEqual(cats, cats.sorted(), "must be category-alphabetical")
    }

    func testCommittedFallsBackToSenior() {
        XCTAssertEqual(ParentWorry.forPhase(.committed).map(\.id),
                       ParentWorry.forPhase(.senior).map(\.id))
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/ParentWorryTests`
Expected: FAIL — `ParentWorry` undefined.

- [ ] **Step 3: Implement model + port all 15 entries**

Open `recruiting-compass-web/utils/parentWorries.ts`. Transcribe every entry in `PARENT_WORRIES` verbatim (`id`, `question`, `answer` strings unchanged). Map `phases` string array → `[TimelinePhase]`; map `category` → `WorryCategory`. Wrap each `question`/`answer` in `String(localized:)`.

Shape (mapping pattern — NOT a real entry; replace with the 15 real ones):
```swift
enum WorryCategory: String, CaseIterable { case academics, mental_health, recruiting, timeline }

struct ParentWorry: Identifiable {
    let id: String
    let question: String
    let answer: String
    let phases: [TimelinePhase]
    let category: WorryCategory

    static let all: [ParentWorry] = [
        ParentWorry(id: "<web id>",
                    question: String(localized: "<web question verbatim>"),
                    answer: String(localized: "<web answer verbatim>"),
                    phases: [.freshman, .sophomore],
                    category: .recruiting),
        // ... all 15 from parentWorries.ts, order preserved
    ]

    static func forPhase(_ phase: TimelinePhase) -> [ParentWorry] {
        let target: TimelinePhase = (phase == .committed) ? .senior : phase
        return all.filter { $0.phases.contains(target) }
                  .sorted { $0.category.rawValue < $1.category.rawValue }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: same `-only-testing:TheRecruitingCompassTests/ParentWorryTests`
Expected: PASS (all 5). If `testDatasetHasFifteenEntries` fails, an entry was dropped — re-check the port.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Models/ParentWorry.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Timeline/ParentWorryTests.swift
git commit -m "feat(timeline): port ParentWorry dataset for Common Worries parity"
```

---

### Task 2: `ReassuranceMessage` model + static dataset (port)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Models/ReassuranceMessage.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Timeline/ReassuranceMessageTests.swift`
- Port source (read verbatim): `recruiting-compass-web/utils/parentReassurance.ts`

**Interfaces:**
- Produces: `struct ReassuranceMessage: Identifiable { let id: String; let title: String; let message: String; let phases: [TimelinePhase]; let icon: String }`; `static func ReassuranceMessage.forPhase(_ phase: TimelinePhase) -> [ReassuranceMessage]` (filter only, **preserve array order — no sort**); `static let all: [ReassuranceMessage]` (8 entries).

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import TheRecruitingCompass

final class ReassuranceMessageTests: XCTestCase {
    func testDatasetHasEightEntries() {
        XCTAssertEqual(ReassuranceMessage.all.count, 8)
    }

    func testEveryEntryHasIcon() {
        XCTAssertTrue(ReassuranceMessage.all.allSatisfy { !$0.icon.isEmpty })
    }

    func testForPhaseFiltersByPhase() {
        let fr = ReassuranceMessage.forPhase(.freshman)
        XCTAssertTrue(fr.allSatisfy { $0.phases.contains(.freshman) })
    }

    func testForPhasePreservesArrayOrder() {
        let ids = ReassuranceMessage.forPhase(.senior).map(\.id)
        let expectedOrder = ReassuranceMessage.all
            .filter { $0.phases.contains(.senior) }.map(\.id)
        XCTAssertEqual(ids, expectedOrder, "must preserve source array order, no sort")
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/ReassuranceMessageTests`
Expected: FAIL — `ReassuranceMessage` undefined.

- [ ] **Step 3: Implement model + port all 8 entries**

Open `recruiting-compass-web/utils/parentReassurance.ts`. Transcribe every `REASSURANCE_MESSAGES` entry verbatim. `icon` = literal emoji string (do NOT localize). Wrap `title`/`message` in `String(localized:)`. Preserve array order.

```swift
struct ReassuranceMessage: Identifiable {
    let id: String
    let title: String
    let message: String
    let phases: [TimelinePhase]
    let icon: String

    static let all: [ReassuranceMessage] = [
        // ... all 8 from parentReassurance.ts, order preserved
    ]

    static func forPhase(_ phase: TimelinePhase) -> [ReassuranceMessage] {
        let target: TimelinePhase = (phase == .committed) ? .senior : phase
        return all.filter { $0.phases.contains(target) }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: same `-only-testing:TheRecruitingCompassTests/ReassuranceMessageTests`
Expected: PASS (all 4).

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Models/ReassuranceMessage.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Timeline/ReassuranceMessageTests.swift
git commit -m "feat(timeline): port ReassuranceMessage dataset for What-Not-To-Stress parity"
```

---

### Task 3: VM keeps top-5 What-Matters-Now items

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/ViewModels/TimelineViewModel.swift` (near `:110`, the `currentTask` assignment)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Timeline/TimelineViewModelWhatMattersTests.swift`

**Interfaces:**
- Consumes: existing `apiService.fetchWhatMattersNow` → `[WhatMattersItem]` (already server-ranked); `WhatMattersItem` (`TimelineAPIModels.swift:24-33`).
- Produces: `TimelineViewModel.whatMattersItems: [WhatMattersItem]` (published, top-5). Existing `currentTask` unchanged.

- [ ] **Step 1: Write the failing test**

Use the project's existing mock `TimelineAPIManaging` pattern (see existing `TimelineViewModel` tests). Stub `fetchWhatMattersNow` to return 7 items; assert VM keeps 5.

```swift
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TimelineViewModelWhatMattersTests: XCTestCase {
    func testKeepsTopFiveWhatMattersItems() async {
        let items = (1...7).map {
            WhatMattersItem(taskId: "t\($0)", title: "T\($0)",
                            whyItMatters: "why", category: "recruiting",
                            priority: 10 - $0, isRequired: true)
        }
        let vm = TimelineViewModel(apiService: MockTimelineAPIService(whatMatters: items))
        await vm.load()
        XCTAssertEqual(vm.whatMattersItems.count, 5)
        XCTAssertEqual(vm.whatMattersItems.map(\.taskId), ["t1","t2","t3","t4","t5"])
        XCTAssertEqual(vm.currentTask?.taskId, "t1")
    }
}
```

Note: match the real `TimelineViewModel` initializer + mock names used in existing tests. If the existing mock lacks a `whatMatters` seam, extend it minimally within this test file's fixtures.

- [ ] **Step 2: Run test, verify it fails**

Run: `cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/TimelineViewModelWhatMattersTests`
Expected: FAIL — `whatMattersItems` undefined.

- [ ] **Step 3: Implement**

Add property + assignment alongside existing `currentTask`:
```swift
var whatMattersItems: [WhatMattersItem] = []
// in load(), where whatMattersResult is fetched:
whatMattersItems = Array(whatMattersResult.prefix(5))
currentTask = whatMattersResult.first
```
Keep the existing non-fatal error path (on failure set both to `[]` / `nil`).

- [ ] **Step 4: Run test, verify pass**

Run: same `-only-testing:...WhatMattersTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/ViewModels/TimelineViewModel.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Timeline/TimelineViewModelWhatMattersTests.swift
git commit -m "feat(timeline): retain top-5 what-matters-now items in VM"
```

---

### Task 4: `CommonWorriesWidget` view

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/CommonWorriesWidget.swift`

**Interfaces:**
- Consumes: `ParentWorry.forPhase(_:)` (Task 1); `TimelinePhase`.
- Produces: `struct CommonWorriesWidget: View { let phase: TimelinePhase }`.

- [ ] **Step 1: Implement the view**

Header "❓ Common Worries" + subtitle "Questions other parents ask at this stage" (`String(localized:)`, match web copy). Body = `ParentWorry.forPhase(phase)` rendered as `DisclosureGroup` accordions (`question` label, `answer` body). Empty → `Text(String(localized: "No common worries at this stage."))`. Follow existing widget card styling (padding, background, corner radius) used by `RecruitingCalendarWidget`. Accessibility: DisclosureGroup label = question.

```swift
struct CommonWorriesWidget: View {
    let phase: TimelinePhase
    var body: some View {
        let worries = ParentWorry.forPhase(phase)
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "❓ Common Worries")).font(.headline)
            Text(String(localized: "Questions other parents ask at this stage"))
                .font(.subheadline).foregroundStyle(.secondary)
            if worries.isEmpty {
                Text(String(localized: "No common worries at this stage."))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(worries) { worry in
                    DisclosureGroup {
                        Text(worry.answer).font(.body)
                    } label: {
                        Text(worry.question).font(.subheadline.weight(.medium))
                    }
                }
            }
        }
        // apply the shared widget-card container modifier used across Timeline/Dashboard
    }
}
```

- [ ] **Step 2: Build verify**

Run build gate. Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/CommonWorriesWidget.swift
git commit -m "feat(timeline): CommonWorriesWidget view"
```

---

### Task 5: `WhatNotToStressWidget` view

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/WhatNotToStressWidget.swift`

**Interfaces:**
- Consumes: `ReassuranceMessage.forPhase(_:)` (Task 2); `TimelinePhase`.
- Produces: `struct WhatNotToStressWidget: View { let phase: TimelinePhase }`.

- [ ] **Step 1: Implement the view**

Header "🛡️ What NOT to Stress About" + subtitle "Things that don't matter as much as you might think". Body = `ReassuranceMessage.forPhase(phase)` rendered as rows: `icon` + `title` (medium) + `message` (body). Empty → "No reassurance needed—you're doing great!". Same card container as Task 4.

```swift
struct WhatNotToStressWidget: View {
    let phase: TimelinePhase
    var body: some View {
        let items = ReassuranceMessage.forPhase(phase)
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "🛡️ What NOT to Stress About")).font(.headline)
            Text(String(localized: "Things that don't matter as much as you might think"))
                .font(.subheadline).foregroundStyle(.secondary)
            if items.isEmpty {
                Text(String(localized: "No reassurance needed—you're doing great!"))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.icon)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.medium))
                            Text(item.message).font(.body).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        // shared widget-card container modifier
    }
}
```

- [ ] **Step 2: Build verify** — build gate, exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/WhatNotToStressWidget.swift
git commit -m "feat(timeline): WhatNotToStressWidget view"
```

---

### Task 6: `UpcomingMilestonesWidget` view (extract)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/UpcomingMilestonesWidget.swift`
- Reference (do not modify): `Core/Utilities/RecruitingCalendar/RecruitingCalendar.swift:241-262`

**Interfaces:**
- Consumes: `RecruitingCalendar.upcomingMilestones(_:sport:division:gender:footballSubdivision:graduationYear:limit:)` → `[CalendarMilestone]`; `CalendarMilestone` (`date, title, type, url?, description?`).
- Produces: `struct UpcomingMilestonesWidget: View { let sport: String?; let gender: String?; let graduationYear: Int? }`.

- [ ] **Step 1: Implement the view**

Header "📅 Upcoming Milestones" + subtitle "Important dates to have on your calendar". Compute `let milestones = RecruitingCalendar.upcomingMilestones(ISO8601 today, sport: sport, division: "D1", gender: gender, graduationYear: graduationYear)`. (Use `"D1"` to match web hardcode — spec open item 3.) Render each: type icon + `title` + formatted `date` + `description`; if `url != nil`, wrap in `Link`. Empty → "No upcoming milestones in the next 6 months." Match the milestone-row styling already inside `RecruitingCalendarWidget` (reuse its row subview if one is factored out; otherwise mirror it).

- [ ] **Step 2: Build verify** — build gate, exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/UpcomingMilestonesWidget.swift
git commit -m "feat(timeline): standalone UpcomingMilestonesWidget"
```

---

### Task 7: `WhatMattersNowWidget` view

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/WhatMattersNowWidget.swift`

**Interfaces:**
- Consumes: `[WhatMattersItem]` (from `TimelineViewModel.whatMattersItems`, Task 3).
- Produces: `struct WhatMattersNowWidget: View { let items: [WhatMattersItem]; let phaseLabel: String }`.

- [ ] **Step 1: Implement the view**

Header "⚡ What Matters Right Now" + subtitle "\(phaseLabel) year priorities to focus on". Render `items` as a numbered list: index badge + `title` + `whyItMatters` (line-limited). Empty → "All tasks complete!". v1 display-only (no tap-through — spec open item 2). Same card container.

```swift
struct WhatMattersNowWidget: View {
    let items: [WhatMattersItem]
    let phaseLabel: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "⚡ What Matters Right Now")).font(.headline)
            Text(String(localized: "\(phaseLabel) year priorities to focus on"))
                .font(.subheadline).foregroundStyle(.secondary)
            if items.isEmpty {
                Text(String(localized: "All tasks complete!"))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1)").font(.caption.weight(.bold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.medium))
                            Text(item.whyItMatters).font(.caption)
                                .foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }
        }
        // shared widget-card container
    }
}
```

- [ ] **Step 2: Build verify** — build gate, exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/WhatMattersNowWidget.swift
git commit -m "feat(timeline): WhatMattersNowWidget view"
```

---

### Task 8: `TimelineGuidanceView` (compose the 5)

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/TimelineGuidanceView.swift`

**Interfaces:**
- Consumes: Tasks 3-7 widgets; `TimelineViewModel` (for `whatMattersItems`, `currentPhase`); athlete `sport/gender/graduationYear` (same inputs the Dashboard passes to `RecruitingCalendarWidget`).
- Produces: `struct TimelineGuidanceView: View { let viewModel: TimelineViewModel; let sport: String?; let gender: String?; let graduationYear: Int? }`.

- [ ] **Step 1: Implement the composition**

`ScrollView > LazyVStack(spacing:16)` in web sidebar order:
1. `WhatMattersNowWidget(items: viewModel.whatMattersItems, phaseLabel: viewModel.currentPhase.displayLabel)`
2. `UpcomingMilestonesWidget(sport:gender:graduationYear:)`
3. `RecruitingCalendarWidget(sport:gender:graduationYear:)` (reuse existing)
4. `CommonWorriesWidget(phase: viewModel.currentPhase)`
5. `WhatNotToStressWidget(phase: viewModel.currentPhase)`

Confirm the exact `currentPhase` property type on `TimelineViewModel` (`TimelinePhase`) and its `displayLabel`. Pad `.horizontal`/`.vertical` to match the Tasks tab.

- [ ] **Step 2: Build verify** — build gate, exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/TimelineGuidanceView.swift
git commit -m "feat(timeline): TimelineGuidanceView composing 5 guidance widgets"
```

---

### Task 9: Segmented control in `RecruitingTimelineView`

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/RecruitingTimelineView.swift` (the `LazyVStack` body, ~`:29-86`)

**Interfaces:**
- Consumes: `TimelineGuidanceView` (Task 8); existing `TimelineMainContent`.
- Produces: `enum TimelineTab: String, CaseIterable, Identifiable { case tasks, guidance }` (with `displayLabel`); `@State private var selectedTab: TimelineTab = .tasks` in the view.

- [ ] **Step 1: Implement**

Keep banner + header + athlete switcher above. Insert the picker, then switch:
```swift
Picker("View", selection: $selectedTab) {
    ForEach(TimelineTab.allCases) { tab in
        Text(tab.displayLabel).tag(tab)
    }
}
.pickerStyle(.segmented)
.padding(.horizontal)

switch selectedTab {
case .tasks:
    TimelineMainContent(...)          // existing, unchanged args
case .guidance:
    TimelineGuidanceView(viewModel: viewModel,
                         sport: <athleteSport>, gender: <athleteGender>,
                         graduationYear: <graduationYear>)
}
```
Source the sport/gender/graduationYear the same way the Dashboard's `DashboardChartsAndDataSection` does for `RecruitingCalendarWidget` (confirm those accessors — likely off the athlete/preferences the VM already holds; if the VM lacks them, thread from the same source the Dashboard uses). `.navigationTitle("Timeline")` stays.

- [ ] **Step 2: Build verify** — build gate, exit 0.

- [ ] **Step 3: Manual sim check**

Launch app → More → Timeline. Toggle `Tasks | Guidance`. Verify: Tasks tab unchanged; Guidance shows 5 widgets in order; worries/reassurance reflect current phase; calendar renders; no layout break in light + dark.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/RecruitingTimelineView.swift
git commit -m "feat(timeline): Tasks|Guidance segmented control on Timeline"
```

---

### Task 10: Localization sweep + full-suite parity gate

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings` (only if any new `String(localized:)` keys are unseeded — the catalog auto-extracts on build; verify no missing/stale entries)

- [ ] **Step 1: Verify catalog**

Build once; open `Localizable.xcstrings`; confirm every new key (widget headings, subtitles, empty states, 15 questions + 15 answers, 8 titles + 8 messages) is present with English values matching the web copy. Do NOT hand-edit unless a key failed to extract.

- [ ] **Step 2: Run the Timeline test suite**

Run:
```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/ParentWorryTests \
  -only-testing:TheRecruitingCompassTests/ReassuranceMessageTests \
  -only-testing:TheRecruitingCompassTests/TimelineViewModelWhatMattersTests
```
Expected: all green. Trust xcodebuild exit code + counts, not a grep.

- [ ] **Step 3: Full build gate**

Run the build gate (clean). Expected: exit 0, no new warnings attributable to this work.

- [ ] **Step 4: Parity cross-check**

Diff iOS `ParentWorry.all` / `ReassuranceMessage.all` against web `parentWorries.ts` / `parentReassurance.ts`: same ids, same phase sets, same category/icon, same question/answer/title/message text. Record confirmation in the handoff. (platform-parity skill.)

- [ ] **Step 5: Commit any catalog delta**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Localizable.xcstrings
git commit -m "chore(timeline): seed guidance-panel localization strings"
```

---

## Self-Review

**Spec coverage:**
- Segmented control → Task 9. ✅
- 5 widgets → Tasks 4-8. ✅
- What Matters top-5 (no ranking port) → Task 3. ✅
- Milestones extract → Task 6. ✅
- Calendar reuse → Task 8 (composition). ✅
- Worries/Reassurance byte-for-byte port + phase filter + sort rules → Tasks 1-2. ✅
- Count + per-phase guards → Tasks 1-2 tests. ✅
- committed→senior fallback → Tasks 1-2 (`forPhase`). ✅
- Localization → Task 10. ✅
- Testing (filter/sort/count/VM) → Tasks 1-3, 10. ✅

**Placeholder scan:** The two dataset "port" steps intentionally reference the canonical web source instead of inlining 23 entries (inlining risks transcription drift; the file IS the spec). Struct, mapping rules, and count-guard tests fully constrain it — an incomplete port fails Task 1/2 tests. All view code blocks are concrete. No TBD/TODO.

**Type consistency:** `forPhase(_:)`, `ParentWorry`, `WorryCategory`, `ReassuranceMessage`, `whatMattersItems`, `TimelineTab`, `WhatMattersItem`, `CalendarMilestone`, `TimelinePhase` used consistently across tasks. Widget init signatures in Tasks 4-7 match their call sites in Task 8.

## Open items carried from spec (resolve during implementation)

1. Whether web `currentPhase` ever emits `committed` to these filters — if web shows empty for committed, change `forPhase` to return `[]` for `.committed` instead of the senior fallback, and update Task 1/2 `testCommittedFallsBackToSenior`.
2. What Matters Now tap-through — v1 display-only; fast-follow if wanted.
3. Milestones `division = "D1"` default — confirm matches web hardcode (Task 6).
