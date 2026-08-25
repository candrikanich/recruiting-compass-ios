# Coach Detail Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the iOS coach detail screen to match the Figma frame (node 13:4): compact identity toolbar, alert banners, ringed KPI cards, colored direct-channels grid, outreach analytics gauge, tags card, profile-meta card — every section boxed — plus `Coach.tags`/`source`, a ported insights engine, and a social-DM return-confirmation.

**Architecture:** MVVM. New pure `CoachInsights` value type (ported from web `useCoachInsights`) drives alerts/stat-cards/analytics. New SwiftUI section components each wrapped in a shared `SectionCard`. `CoachDetailViewModel` gains insights, a `pendingSocialDM` prompt seam, tags persistence, and interaction creation. No migration (shared DB already has the columns).

**Tech Stack:** Swift 6, SwiftUI, `@Observable @MainActor` view models, XCTest, SwiftLint.

**Spec:** `docs/superpowers/specs/2026-08-25-coach-detail-redesign-ios-design.md`

## Global Constraints

- Branch: `feat/coach-detail-redesign` (already created, spec committed). PR → `main`.
- Build/test destination: `platform=iOS Simulator,name=iPhone 17`; prefix `xcodebuild` with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- SwiftLint: `swiftlint lint --config .swiftlint.yml` (also needs `DEVELOPER_DIR`). Rule `viewbuilder_on_some_view`: every computed `some View` property except `body` needs `@ViewBuilder`. Line length ≤ 120.
- `@MainActor` classes need `nonisolated deinit {}`. ViewModels are `@Observable @MainActor`; services are `protocol : Sendable`.
- Validation caps (verbatim from spec §2): tags ≤ **20** items, each trimmed non-empty ≤ **40** chars; `source` ≤ **80** chars.
- `OVERDUE_DAYS = 14`; `isOverdue` is strictly `daysSinceContact > 14`.
- New fields on `Coach`/requests must be added with **default values** in explicit inits so existing call sites compile unchanged.
- Source lives under `TheRecruitingCompass/TheRecruitingCompass/`; tests under `TheRecruitingCompass/TheRecruitingCompassTests/`. All paths below are relative to repo root.
- Run all commands from `TheRecruitingCompass/` (the Xcode project wrapper).

---

### Task 1: Add `tags` / `source` to the `Coach` model

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/Coach.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/Models/CoachDecodingTests.swift` (create if absent; else add to the existing Coach model test file)

**Interfaces:**
- Produces: `Coach.tags: [String]`, `Coach.source: String?`; explicit init gains `tags: [String] = []`, `source: String? = nil` (defaulted).

- [ ] **Step 1: Write failing tests** — decode with/without the keys, and defaulting.

```swift
import XCTest
@testable import TheRecruitingCompass

final class CoachDecodingTests: XCTestCase {
  nonisolated deinit {}

  private func decode(_ json: String) throws -> Coach {
    try JSONDecoder().decode(Coach.self, from: Data(json.utf8))
  }

  func testDecode_withTagsAndSource() throws {
    let coach = try decode(#"""
    {"id":"c1","first_name":"Dana","last_name":"Whitfield","school_id":"s1",
     "created_at":"2026-01-15T00:00:00Z","updated_at":"2026-08-10T00:00:00Z",
     "tags":["Football","Division I"],"source":"LinkedIn"}
    """#)
    XCTAssertEqual(coach.tags, ["Football", "Division I"])
    XCTAssertEqual(coach.source, "LinkedIn")
  }

  func testDecode_missingTagsAndSource_defaults() throws {
    let coach = try decode(#"""
    {"id":"c1","first_name":"Dana","last_name":"Whitfield","school_id":"s1",
     "created_at":"2026-01-15T00:00:00Z","updated_at":"2026-08-10T00:00:00Z"}
    """#)
    XCTAssertEqual(coach.tags, [])
    XCTAssertNil(coach.source)
  }
}
```

- [ ] **Step 2: Run — expect FAIL** (`value of type 'Coach' has no member 'tags'`).

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/CoachDecodingTests`

- [ ] **Step 3: Implement** in `Coach.swift`:
  - Add stored props after `notes`: `let tags: [String]` and `let source: String?`.
  - Add to `CodingKeys`: `case tags` and `case source`.
  - In `init(from:)`: `tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []` and `source = try container.decodeIfPresent(String.self, forKey: .source)`.
  - In `encode(to:)`: `try container.encode(tags, forKey: .tags)` and `try container.encodeIfPresent(source, forKey: .source)`.
  - In the explicit memberwise `init(...)`: add params `tags: [String] = [], source: String? = nil` (defaulted — do NOT reorder existing params; append before `createdAt` or at a natural spot) and assign `self.tags = tags`, `self.source = source`.

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/Coach.swift TheRecruitingCompass/TheRecruitingCompassTests/Features/Dashboard/Models/CoachDecodingTests.swift
git commit -m "feat(coaches): add tags/source to Coach model"
```

---

### Task 2: Plumb `tags` / `source` through requests, `EditableCoach`, `CoachFormState` + validation

**Files:**
- Modify: `Features/Coaches/Models/CoachCreateRequest.swift`, `Features/Coaches/Models/CoachUpdateRequest.swift`, `Features/Coaches/Models/EditableCoach.swift`, `Features/Coaches/Models/CoachFormState.swift`
- Create: `Features/Coaches/Models/CoachTagsValidator.swift`
- Test: `TheRecruitingCompassTests/Features/Coaches/Models/CoachTagsValidatorTests.swift`

**Interfaces:**
- Consumes: `Coach.tags`/`source` (Task 1).
- Produces: `CoachTagsValidator.sanitize(_ tags: [String]) -> [String]` (trim, drop empty/dupes, cap 20 / 40 chars); `CoachTagsValidator.sanitizeSource(_:) -> String?` (trim, cap 80, nil-if-empty); `CoachCreateRequest`/`CoachUpdateRequest` gain `tags`/`source` encodable fields (`"tags"`, `"source"`); `EditableCoach.tags: [String]`, `EditableCoach.source: String`.

- [ ] **Step 1: Write failing tests** for `CoachTagsValidator`.

```swift
import XCTest
@testable import TheRecruitingCompass

final class CoachTagsValidatorTests: XCTestCase {
  nonisolated deinit {}

  func testSanitize_trimsDropsEmptyAndDupes() {
    XCTAssertEqual(
      CoachTagsValidator.sanitize(["  Football ", "Football", "", "   ", "Referral"]),
      ["Football", "Referral"]
    )
  }

  func testSanitize_capsAt20Items() {
    let input = (1...25).map { "tag\($0)" }
    XCTAssertEqual(CoachTagsValidator.sanitize(input).count, 20)
  }

  func testSanitize_dropsTagsOver40Chars() {
    let long = String(repeating: "a", count: 41)
    XCTAssertEqual(CoachTagsValidator.sanitize([long, "ok"]), ["ok"])
  }

  func testSanitizeSource_capsAt80AndNilIfEmpty() {
    XCTAssertNil(CoachTagsValidator.sanitizeSource("   "))
    XCTAssertEqual(CoachTagsValidator.sanitizeSource("LinkedIn"), "LinkedIn")
    XCTAssertNil(CoachTagsValidator.sanitizeSource(String(repeating: "a", count: 81)),
                 "over-cap source is rejected (nil), not truncated")
  }
}
```

- [ ] **Step 2: Run — expect FAIL** (no `CoachTagsValidator`).

- [ ] **Step 3: Implement** `CoachTagsValidator.swift`:

```swift
import Foundation

/// Client-side caps for coach tags/source, mirroring the web Zod `coachSchema`
/// (tags ≤ 20 items / ≤ 40 chars each; source ≤ 80 chars).
enum CoachTagsValidator {
  static let maxTags = 20
  static let maxTagLength = 40
  static let maxSourceLength = 80

  static func sanitize(_ tags: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for raw in tags {
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, trimmed.count <= maxTagLength, !seen.contains(trimmed) else { continue }
      seen.insert(trimmed)
      out.append(trimmed)
      if out.count == maxTags { break }
    }
    return out
  }

  static func sanitizeSource(_ source: String?) -> String? {
    guard let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty, trimmed.count <= maxSourceLength else { return nil }
    return trimmed
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Wire requests + editable/form state** (no new test — exercised by Task 12/14):
  - `CoachCreateRequest`: add `let tags: [String]` and `let source: String?`, `case tags`, `case source`. Update any initializer/call site that builds it (search `CoachCreateRequest(`).
  - `CoachUpdateRequest`: add `let tags: [String]?`, `let source: String?`, `case tags`, `case source`, and init params `tags: [String]? = nil, source: String? = nil` (defaulted — preserves single-field-update callers).
  - `EditableCoach`: add `var tags: [String]` and `var source: String`; seed from `Coach` in `init(from:)`; include in `toUpdateRequest()` as `tags: CoachTagsValidator.sanitize(tags), source: CoachTagsValidator.sanitizeSource(source)`.
  - `CoachFormState`: add `var tags: [String] = []` and `var source: String = ""`; include in its create-request builder via the same sanitizers.

- [ ] **Step 6: Build + commit.**

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Models/ TheRecruitingCompassTests/Features/Coaches/Models/CoachTagsValidatorTests.swift
git commit -m "feat(coaches): plumb tags/source through requests + form state with caps"
```

---

### Task 3: `CoachInsights` — port `useCoachInsights`

**Files:**
- Create: `Features/Coaches/Models/CoachInsights.swift`
- Test: `TheRecruitingCompassTests/Features/Coaches/Models/CoachInsightsTests.swift`

**Interfaces:**
- Consumes: `Coach` (`lastContactDateParsed`), `[Interaction]` (`occurredAt`, `displayDate`, `direction`, `type`).
- Produces:
  ```swift
  struct CoachInsights: Sendable {
    let daysSinceContact: Int?
    let isOverdue: Bool
    let totalInteractions: Int
    let sent: Int
    let received: Int
    let responseRate: Int          // integer percent
    let preferredChannel: InteractionType?
    var overdueAlert: Bool { isOverdue }
    var channelPreferenceAlert: Bool { preferredChannel != nil && totalInteractions >= 1 }
    static func make(coach: Coach?, interactions: [Interaction], now: Date = .now) -> CoachInsights
  }
  ```

- [ ] **Step 1: Write failing tests.**

```swift
import XCTest
@testable import TheRecruitingCompass

final class CoachInsightsTests: XCTestCase {
  nonisolated deinit {}

  private let now = ISO8601DateFormatter().date(from: "2026-08-25T12:00:00Z")!

  private func interaction(
    _ id: String, type: InteractionType = .email, direction: Direction = .outbound, daysAgo: Int
  ) -> Interaction {
    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
    let iso = ISO8601DateFormatter().string(from: date)
    return Interaction(
      id: id, type: type, direction: direction, schoolId: "s1", coachId: "c1",
      subject: nil, content: nil, sentiment: nil, occurredAt: iso, loggedBy: "u1",
      attachments: nil, familyUnitId: "f1", createdAt: iso, updatedAt: nil)
  }

  private func coach(lastContactDaysAgo: Int?) -> Coach {
    let last = lastContactDaysAgo.map {
      ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -$0, to: now)!)
    }
    return Coach(id: "c1", firstName: "Dana", lastName: "Whitfield", schoolId: "s1",
                 lastContactDate: last, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-08-01T00:00:00Z")
  }

  func testOverdueBoundary_14NotOverdue_15Overdue() {
    let notOverdue = CoachInsights.make(coach: coach(lastContactDaysAgo: 14), interactions: [], now: now)
    XCTAssertEqual(notOverdue.daysSinceContact, 14)
    XCTAssertFalse(notOverdue.isOverdue)
    let overdue = CoachInsights.make(coach: coach(lastContactDaysAgo: 15), interactions: [], now: now)
    XCTAssertTrue(overdue.isOverdue)
  }

  func testDaysSince_prefersNewestInteractionOverStored() {
    let i = CoachInsights.make(
      coach: coach(lastContactDaysAgo: 30),
      interactions: [interaction("1", daysAgo: 5), interaction("2", daysAgo: 1)], now: now)
    XCTAssertEqual(i.daysSinceContact, 1)
  }

  func testSentReceivedAndResponseRate() {
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: 2), interactions: [
      interaction("1", direction: .outbound, daysAgo: 3),
      interaction("2", direction: .inbound, daysAgo: 2),
      interaction("3", direction: .inbound, daysAgo: 1)
    ], now: now)
    XCTAssertEqual(i.sent, 1)
    XCTAssertEqual(i.received, 2)
    XCTAssertEqual(i.responseRate, 67)   // round(2/3*100)
  }

  func testPreferredChannel_modeOfType() {
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: 2), interactions: [
      interaction("1", type: .email, daysAgo: 3),
      interaction("2", type: .email, daysAgo: 2),
      interaction("3", type: .phoneCall, daysAgo: 1)
    ], now: now)
    XCTAssertEqual(i.preferredChannel, .email)
  }

  func testEmpty_nilsAndZeroes() {
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: nil), interactions: [], now: now)
    XCTAssertNil(i.daysSinceContact)
    XCTAssertFalse(i.isOverdue)
    XCTAssertNil(i.preferredChannel)
    XCTAssertFalse(i.channelPreferenceAlert)
    XCTAssertEqual(i.responseRate, 0)
  }

  func testIgnoresNilOccurredAt() {
    let dateless = Interaction(
      id: "x", type: .email, direction: .outbound, schoolId: "s1", coachId: "c1",
      subject: nil, content: nil, sentiment: nil, occurredAt: nil, loggedBy: "u1",
      attachments: nil, familyUnitId: "f1", createdAt: "2026-08-24T00:00:00Z", updatedAt: nil)
    let i = CoachInsights.make(coach: coach(lastContactDaysAgo: 7), interactions: [dateless], now: now)
    XCTAssertEqual(i.daysSinceContact, 7)  // falls back to stored, not "today"
  }
}
```

- [ ] **Step 2: Run — expect FAIL** (no `CoachInsights`). Confirm `Direction` has `.inbound`/`.outbound` first (`grep -rn "enum Direction" Features/Interactions/Models`); if the inbound case has a different name, use it in the tests.

- [ ] **Step 3: Implement** `CoachInsights.swift`:

```swift
import Foundation

/// Derived coach metrics — a pure port of the web `useCoachInsights` composable
/// so both platforms show identical numbers. OVERDUE_DAYS = 14.
struct CoachInsights: Sendable {
  let daysSinceContact: Int?
  let isOverdue: Bool
  let totalInteractions: Int
  let sent: Int
  let received: Int
  let responseRate: Int
  let preferredChannel: InteractionType?

  var overdueAlert: Bool { isOverdue }
  var channelPreferenceAlert: Bool { preferredChannel != nil && totalInteractions >= 1 }

  static let overdueDays = 14

  static func make(coach: Coach?, interactions: [Interaction], now: Date = .now) -> CoachInsights {
    let calendar = Calendar.current

    let latest = interactions.filter { $0.occurredAt != nil }.map(\.displayDate).max()
    let days: Int? = {
      if let latest { return calendar.dateComponents([.day], from: latest, to: now).day }
      guard let stored = coach?.lastContactDateParsed else { return nil }
      return calendar.dateComponents([.day], from: stored, to: now).day
    }()

    let total = interactions.count
    let sent = interactions.filter { $0.direction == .outbound }.count
    let received = total - sent
    let rate = total == 0 ? 0 : Int((Double(received) / Double(total) * 100).rounded())

    let preferred: InteractionType? = {
      guard !interactions.isEmpty else { return nil }
      var counts: [InteractionType: Int] = [:]
      var order: [InteractionType] = []
      for i in interactions where counts[i.type] == nil { order.append(i.type) }
      for i in interactions { counts[i.type, default: 0] += 1 }
      return order.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) })
    }()

    return CoachInsights(
      daysSinceContact: days,
      isOverdue: days != nil && days! > overdueDays,
      totalInteractions: total,
      sent: sent, received: received, responseRate: rate,
      preferredChannel: preferred)
  }
}
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Models/CoachInsights.swift TheRecruitingCompassTests/Features/Coaches/Models/CoachInsightsTests.swift
git commit -m "feat(coaches): CoachInsights — port useCoachInsights (overdue/preferred/response-rate)"
```

---

### Task 4: Wire `CoachInsights` into `CoachDetailViewModel`

**Files:**
- Modify: `Features/Coaches/ViewModels/CoachDetailViewModel.swift`
- Test: `TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `CoachInsights.make` (Task 3).
- Produces: `CoachDetailViewModel.insights: CoachInsights?`, set in `loadDetails()`. Existing `stats` stays for now (Task 8 restyles the grid off `insights`).

- [ ] **Step 1: Write failing test.**

```swift
func testLoadDetails_populatesInsights() async {
  await sut.loadCoach()
  mockService.stubbedInteractions = [
    makeInteraction(id: "1", type: .email, occurredAt: iso8601(daysAgo: 1))
  ]
  await sut.loadDetails()
  XCTAssertNotNil(sut.insights)
  XCTAssertEqual(sut.insights?.totalInteractions, 1)
  XCTAssertEqual(sut.insights?.daysSinceContact, 1)
}
```

- [ ] **Step 2: Run — expect FAIL** (no `insights`).

- [ ] **Step 3: Implement:** add `var insights: CoachInsights?` stored property; in `loadDetails()` after setting `recentInteractions`, add `insights = CoachInsights.make(coach: coach, interactions: recentInteractions)`. Leave `computeStats()`/`stats` intact.

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachDetailViewModel.swift TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachDetailViewModelTests.swift
git commit -m "feat(coaches): expose CoachInsights on CoachDetailViewModel"
```

---

### Task 5: `SectionCard` container + `sky500`/`fuchsia500` tokens

**Files:**
- Create: `Features/Coaches/Components/SectionCard.swift`
- Modify: `Core/Theme/AppColors.swift`

**Interfaces:**
- Produces: `SectionCard<Content: View>` with optional uppercase `label`; `Color.Brand.sky500`, `Color.Brand.fuchsia500`.

- [ ] **Step 1: Add tokens** in `AppColors.swift` `Brand` enum: `static let sky500 = Color(hex: "0ea5e9")` and `static let fuchsia500 = Color(hex: "d946ef")`.

- [ ] **Step 2: Implement** `SectionCard.swift`:

```swift
import SwiftUI

/// Boxed section container matching the coach-detail Figma frame: an optional
/// uppercase label above content, on an elevated rounded card.
struct SectionCard<Content: View>: View {
  var label: LocalizedStringKey?
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let label {
        Text(label)
          .font(.caption.bold())
          .textCase(.uppercase)
          .foregroundStyle(Color.secondaryText)
          .tracking(0.5)
      }
      content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(uiColor: .secondarySystemBackground))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(uiColor: .separator), lineWidth: 1))
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}
```

- [ ] **Step 3: Build** (no unit test — visual container; verified via Task 15 previews).

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`

- [ ] **Step 4: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/SectionCard.swift TheRecruitingCompass/TheRecruitingCompass/Core/Theme/AppColors.swift
git commit -m "feat(coaches): SectionCard container + sky500/fuchsia500 tokens"
```

---

### Task 6: Rebuild `CoachDetailHeader` as the identity toolbar

**Files:**
- Modify: `Features/Coaches/Components/CoachDetailHeader.swift`

**Interfaces:**
- Consumes: `SchoolLogoAvatar` (shipped), `Coach`, `School?`.
- Produces: `CoachDetailHeader(coach:school:onEdit:onDelete:)` — horizontal toolbar; `onEdit`/`onDelete` are `() -> Void`.

- [ ] **Step 1: Implement** the rebuilt header (replaces the centered 100pt avatar body):

```swift
import SwiftUI

/// Compact identity toolbar: small school-logo avatar, name + role, and
/// edit / delete actions — matching the coach-detail Figma frame.
struct CoachDetailHeader: View {
  let coach: Coach
  let school: School?
  var onEdit: () -> Void = {}
  var onDelete: () -> Void = {}

  var body: some View {
    HStack(spacing: 12) {
      SchoolLogoAvatar(logoUrl: school?.faviconUrl, initials: coach.initials,
                       size: 40, accessibilitySize: 52, cornerRadius: 10)

      VStack(alignment: .leading, spacing: 2) {
        Text(coach.fullName)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Text(coach.role.displayName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      iconButton(system: "pencil", tint: Color.Brand.blue600, bg: Color.Brand.blue100,
                 label: "Edit coach", action: onEdit)
      iconButton(system: "trash", tint: Color.Brand.red600, bg: Color.Brand.red100,
                 label: "Delete coach", action: onDelete)
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func iconButton(system: String, tint: Color, bg: Color,
                          label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .accessibilityLabel(label)
  }
}
```

- [ ] **Step 2: Build.** (Existing `CoachDetailComponentsTests` may construct `CoachDetailHeader(coach:school:)` — the defaulted `onEdit`/`onDelete` keep it compiling.)

- [ ] **Step 3: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/CoachDetailHeader.swift
git commit -m "feat(coaches): rebuild CoachDetailHeader as identity toolbar with edit/delete"
```

---

### Task 7: `CoachAlertsSection`

**Files:**
- Create: `Features/Coaches/Components/CoachAlertsSection.swift`

**Interfaces:**
- Consumes: `CoachInsights`.
- Produces: `CoachAlertsSection(insights: CoachInsights)` — renders 0/1/2 banners.

- [ ] **Step 1: Implement:**

```swift
import SwiftUI

/// Conditional alert banners (Outreach Overdue / Channel Preference). Either,
/// both, or neither may show — matching the coach-detail Figma frame.
struct CoachAlertsSection: View {
  let insights: CoachInsights

  var body: some View {
    VStack(spacing: 12) {
      if insights.overdueAlert, let days = insights.daysSinceContact {
        banner(icon: "exclamationmark.triangle.fill",
               tint: Color.Brand.red600, bg: Color.errorBackground, border: Color.errorBorder,
               title: "Urgent: Outreach Overdue",
               body: "No contact in \(days) days – reach out immediately to maintain connection.")
      }
      if insights.channelPreferenceAlert, let channel = insights.preferredChannel {
        banner(icon: "info.circle.fill",
               tint: Color.Brand.blue600, bg: Color.Brand.blue100, border: Color.Brand.blue100,
               title: "Channel Preference detected",
               body: "Prefers responding via \(channel.displayName).")
      }
    }
  }

  @ViewBuilder
  private func banner(icon: String, tint: Color, bg: Color, border: Color,
                      title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(tint)
        .clipShape(Circle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.bold()).foregroundStyle(tint)
        Text(body).font(.footnote).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(bg)
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
    .clipShape(.rect(cornerRadius: 12))
    .accessibilityElement(children: .combine)
  }
}
```

- [ ] **Step 2: Build + commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/CoachAlertsSection.swift
git commit -m "feat(coaches): CoachAlertsSection — overdue + channel-preference banners"
```

---

### Task 8: Restyle `CoachStatsGrid` off `CoachInsights` (rings + OVERDUE pill)

**Files:**
- Modify: `Features/Coaches/Components/CoachStatsGrid.swift`

**Interfaces:**
- Consumes: `CoachInsights`.
- Produces: `CoachStatsGrid(insights: CoachInsights)` — 3 ringed KPI cards (DAYS SINCE / INTERACTIONS / PREFERRED).

- [ ] **Step 1: Reimplement** `CoachStatsGrid` to take `insights` and render per the frame:
  - DAYS SINCE: label "DAYS SINCE"; value `insights.daysSinceContact.map { "\($0)" } ?? "—"` (red when `isOverdue`); a red **OVERDUE** capsule when `isOverdue`; a decorative red ring on the right.
  - INTERACTIONS: label "INTERACTIONS"; value `"\(insights.totalInteractions)"`; sub `"\(insights.totalInteractions) logged"`; blue ring.
  - PREFERRED: label "PREFERRED"; value `insights.preferredChannel?.displayName ?? "—"` (`.lineLimit(1).truncationMode(.tail)`); sub `"\(insights.responseRate)% rate"` in green; orange ring.
  - Ring = `Circle().stroke(color, lineWidth: 3).frame(width: 32, height: 32)` (decorative, `accessibilityHidden(true)` — spec §6.1: not proportional).
  - Overdue card gets a red border/tint; others plain. Cards in a 3-col `LazyVGrid`; each `.accessibilityElement(children: .combine)` with a combined label.
  - Keep `CoachStats` type unused-by-this-view; do not delete it yet (Task 15 removes the old `stats` feed if nothing else uses it).

- [ ] **Step 2: Build.** Update the `#Preview` to pass a `CoachInsights` sample.

- [ ] **Step 3: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/CoachStatsGrid.swift
git commit -m "feat(coaches): restyle KPI stat cards off CoachInsights (rings + OVERDUE pill)"
```

---

### Task 9: `CoachDirectChannelsGrid`

**Files:**
- Create: `Features/Coaches/Components/CoachDirectChannelsGrid.swift`

**Interfaces:**
- Consumes: `Coach`, `Color.Brand.sky500`/`fuchsia500` (Task 5).
- Produces: `CoachDirectChannelsGrid(coach:onEmail:onText:onCall:onTwitter:onInstagram:onLog:)` — 2×3 filled pill buttons; each closure `() -> Void`.

- [ ] **Step 1: Implement** a 2-row × 3-col `LazyVGrid` of filled pill buttons (icon + label, white text, ≥44pt), colors: Email `blue500`, Text `emerald500`, Call `orange500`, Twitter `sky500`, Instagram `LinearGradient([fuchsia500, pink500])`, Log Activity `slate700`. Use brand-mark assets `LogoX`/`LogoInstagram` for Twitter/Instagram (template-rendered white), SF Symbols (`envelope.fill`/`message.fill`/`phone.fill`/`plus`) for the rest. Each button `.accessibilityLabel(...)`. Buttons for email/text/call only render when the coach has that contact field; Twitter/Instagram only when the handle exists; Log Activity always.

- [ ] **Step 2: Build + commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/CoachDirectChannelsGrid.swift
git commit -m "feat(coaches): CoachDirectChannelsGrid — colored 2x3 action grid"
```

---

### Task 10: Social-DM return-confirmation (ViewModel seam + interaction write)

**Files:**
- Modify: `Features/Coaches/ViewModels/CoachDetailViewModel.swift`
- Test: `TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `InteractionsManaging.createInteraction(_:)`, `InteractionCreateRequest`.
- Produces on the VM:
  ```swift
  enum SocialChannel: Sendable { case twitter, instagram }
  struct PendingSocialDM: Equatable, Sendable { let channel: SocialChannel; let coachId: String; let coachName: String }
  var pendingSocialDM: PendingSocialDM?
  func armSocialDM(_ channel: SocialChannel)          // sets pendingSocialDM from current coach
  func confirmSocialDM() async                        // logs .directMessage outbound, reloads, clears
  func dismissSocialDM()                              // clears
  ```
  The VM needs an injected `InteractionsManaging` (add to init, default `InteractionsServiceImpl(...)`).

- [ ] **Step 1: Write failing tests** (extend the existing test file; add a `MockInteractionsService` if none — a minimal stub capturing the last `InteractionCreateRequest`).

```swift
func testArmSocialDM_setsPending() async {
  await sut.loadCoach()
  sut.armSocialDM(.twitter)
  XCTAssertEqual(sut.pendingSocialDM?.channel, .twitter)
  XCTAssertEqual(sut.pendingSocialDM?.coachId, "coach-1")
}

func testConfirmSocialDM_logsOutboundDMAndClears() async {
  await sut.loadCoach()
  sut.armSocialDM(.instagram)
  await sut.confirmSocialDM()
  XCTAssertEqual(mockInteractions.lastCreated?.type, InteractionType.directMessage.rawValue)
  XCTAssertEqual(mockInteractions.lastCreated?.direction, Direction.outbound.rawValue)
  XCTAssertEqual(mockInteractions.lastCreated?.coachId, "coach-1")
  XCTAssertNil(sut.pendingSocialDM)
}

func testDismissSocialDM_writesNothing() async {
  await sut.loadCoach()
  sut.armSocialDM(.twitter)
  sut.dismissSocialDM()
  XCTAssertNil(sut.pendingSocialDM)
  XCTAssertNil(mockInteractions.lastCreated)
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement:**
  - Inject `interactionsService: any InteractionsManaging` (default `InteractionsServiceImpl(supabaseManager: .shared)`) into the VM init; store it.
  - Add the `SocialChannel`/`PendingSocialDM` types and `pendingSocialDM` property.
  - `armSocialDM`: `guard let coach else { return }; pendingSocialDM = .init(channel: channel, coachId: coach.id, coachName: coach.fullName)`.
  - `confirmSocialDM`: guard pending + `coach` + `authManager.user?.id` + resolve `familyUnitId` (via `allSchools.first { $0.id == coach.schoolId }?.familyUnitId`, same pattern as `invalidateCoachCache`); build `InteractionCreateRequest(schoolId: coach.schoolId, coachId: coach.id, type: .directMessage, direction: .outbound, occurredAt: .now, subject: channel == .twitter ? "Twitter DM" : "Instagram DM", content: nil, sentiment: nil, loggedBy: userId, familyUnitId: familyUnitId)`; `try await interactionsService.createInteraction(request)`; then `await loadDetails()`; clear pending. Wrap in do/catch → `errorMessage`.
  - `dismissSocialDM`: `pendingSocialDM = nil`.

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachDetailViewModel.swift TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachDetailViewModelTests.swift
git commit -m "feat(coaches): social-DM return-confirmation seam on CoachDetailViewModel"
```

---

### Task 11: `CoachAnalyticsCard`

**Files:**
- Create: `Features/Coaches/Components/CoachAnalyticsCard.swift`

**Interfaces:**
- Consumes: `CoachInsights`.
- Produces: `CoachAnalyticsCard(insights: CoachInsights)`.

- [ ] **Step 1: Implement** to match the frame: title "Outreach History & Analytics" with a static "All Time" label top-right; a **Sent / Received** row (`"\(insights.sent)/\(insights.received)"`) over a two-tone capsule bar (blue sent / green received, widths proportional to sent vs received, guarding divide-by-zero → empty bar); a **Response Rate** row (`"\(insights.responseRate)%"`) over a green `ProgressView(value:)`-style capsule filled to `responseRate/100`; and a right-side ring gauge: `Circle().trim(from: 0, to: CGFloat(insights.responseRate)/100).stroke(Color.Brand.emerald500, style: .init(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))` with `"\(insights.responseRate)%"` centered and a caption ("Great Progress" when `responseRate >= 50`, else "Keep going"). `.accessibilityElement(children: .combine)`.

- [ ] **Step 2: Build + commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/CoachAnalyticsCard.swift
git commit -m "feat(coaches): CoachAnalyticsCard — sent/received + response-rate gauge"
```

---

### Task 12: `CoachTagsCard` + tags persistence on the VM

**Files:**
- Create: `Features/Coaches/Components/CoachTagsCard.swift`
- Modify: `Features/Coaches/ViewModels/CoachDetailViewModel.swift`
- Test: `TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachDetailViewModelTests.swift`

**Interfaces:**
- Produces on the VM: `func saveTags(_ tags: [String]) async` — sanitizes via `CoachTagsValidator`, writes `CoachUpdateRequest(tags:)`, updates `coach`, invalidates cache. `CoachTagsCard(tags:onAdd:onRemove:)`.

- [ ] **Step 1: Write failing test.**

```swift
func testSaveTags_sanitizesAndPersists() async {
  await sut.loadCoach()
  await sut.saveTags(["  Football ", "Football", ""])   // dupes/empties dropped
  XCTAssertEqual(mockService.lastUpdate?.tags, ["Football"])
}
```
(Extend `MockCoachesService` to capture `lastUpdate: CoachUpdateRequest?` if not already.)

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement** `saveTags` on the VM (sanitize → `updateCoach(id:updates: CoachUpdateRequest(tags: sanitized))` → set `coach` → `invalidateCoachCache()`), then `CoachTagsCard`: wrapping chips (`slate100` bg, `slate600` text, rounded) each with a remove `xmark` when editable; a "+ Add Tag" (`blue600`) control opening a small `.alert`/text field that appends via `onAdd`. Caps enforced by the VM sanitizer.

- [ ] **Step 4: Run — expect PASS. Build.**

- [ ] **Step 5: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/CoachTagsCard.swift TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachDetailViewModel.swift TheRecruitingCompassTests/Features/Coaches/ViewModels/CoachDetailViewModelTests.swift
git commit -m "feat(coaches): CoachTagsCard + tag persistence with caps"
```

---

### Task 13: `CoachProfileMetaCard`

**Files:**
- Create: `Features/Coaches/Components/CoachProfileMetaCard.swift`

**Interfaces:**
- Consumes: `Coach` (`createdAt`, `source`, `updatedAt`).
- Produces: `CoachProfileMetaCard(coach: Coach)`.

- [ ] **Step 1: Implement** three key/value rows (label left secondary, value right primary bold): Coach Since = formatted `createdAt`, Source = `coach.source ?? "—"`, Last Updated = formatted `updatedAt`. Add a small private ISO→"MMM d, yyyy" formatter (parse with the same two ISO formatters `Interaction` uses; fall back to the raw string). `.accessibilityElement(children: .combine)` per row.

- [ ] **Step 2: Build + commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Components/CoachProfileMetaCard.swift
git commit -m "feat(coaches): CoachProfileMetaCard — coach since / source / last updated"
```

---

### Task 14: Tags + Source inputs in the create/edit forms

**Files:**
- Modify: `Features/Coaches/Views/CoachEditForm.swift`, `Features/Coaches/Views/AddCoachView.swift` (and `CoachFormView.swift` if it hosts the shared fields)

**Interfaces:**
- Consumes: `EditableCoach.tags`/`source`, `CoachFormState.tags`/`source`, `CoachTagsValidator`.

- [ ] **Step 1: Add** a Tags chip editor (reuse the `CoachTagsCard` editable chip layout or a `Form`-friendly variant: existing chips with remove + an add field) bound to the form's `tags`, and a Source `TextField` bound to `source`, in both the edit form and the add form. Enforce caps on commit via `CoachTagsValidator` (already applied in `toUpdateRequest()`/create builder from Task 2 — the form just prevents adding past 20 / 40 chars and shows a subtle limit hint).

- [ ] **Step 2: Build.** If a form-validation test file exists for coaches, add a case asserting a 21st tag is rejected; otherwise rely on Task 2's validator tests.

- [ ] **Step 3: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/
git commit -m "feat(coaches): tags + source inputs in create/edit coach forms"
```

---

### Task 15: Recompose `CoachDetailView` + wire everything

**Files:**
- Modify: `Features/Coaches/Views/CoachDetailView.swift`
- Test: `TheRecruitingCompassTests/Features/Coaches/Views/CoachDetailViewTests.swift`, `TheRecruitingCompassTests/Features/Coaches/Components/CoachDetailComponentsTests.swift`, `TheRecruitingCompassTests/Accessibility/CoachDetailAccessibilityTests.swift`

**Interfaces:**
- Consumes: every component from Tasks 5–13, VM seams from Tasks 4/10/12.

- [ ] **Step 1: Rebuild `detailContent`** as an ordered stack of boxed sections (spec §4):
  1. `SectionCard { CoachDetailHeader(coach:school:onEdit:{viewModel.startEditing()}, onDelete:{viewModel.confirmDelete()}) }`
  2. `if let insights = viewModel.insights { CoachAlertsSection(insights: insights) }` (banners are self-boxed, no `SectionCard`)
  3. `if let insights { SectionCard { CoachStatsGrid(insights: insights) } }`
  4. `SectionCard(label: "Direct Channels") { CoachDirectChannelsGrid(coach: coach, onEmail:…, onText:…, onCall:…, onTwitter: { openURL(twitterURL); viewModel.armSocialDM(.twitter) }, onInstagram: { openURL(igURL); viewModel.armSocialDM(.instagram) }, onLog: { presentLogInteraction() }) }`
  5. `if let insights { SectionCard { CoachAnalyticsCard(insights: insights) } }`
  6. `SectionCard(label: "Interactions History") { CoachInteractionsLogSection(viewModel: viewModel) }`
  7. `SectionCard(label: "Internal Notes") { sharedNotesSection }`
  8. `CoachTagsCard(...)` inside `SectionCard(label: "Tags")` bound to `viewModel.coach?.tags`, `onAdd/onRemove → Task { await viewModel.saveTags(newTags) }`
  9. `SectionCard(label: "Profile Meta") { CoachProfileMetaCard(coach: coach) }`
  - Keep the existing Send-Profile section boxed as its own `SectionCard` (from PR #62), placed per the frame (after analytics or before notes — pick after Interactions).
  - Twitter/Instagram open: build the URL via `CommunicationType.twitter(handle).url(for:)`/`.instagram`, open with `@Environment(\.openURL)`, then `armSocialDM`.
- [ ] **Step 2: Add the return-confirmation** — `@Environment(\.scenePhase) private var scenePhase`, and `.onChange(of: scenePhase) { _, phase in if phase == .active, viewModel.pendingSocialDM != nil { showSocialDMConfirit = true } }`; a `.confirmationDialog` presenting *"Did you send \(name) a DM on \(channel)?"* with **Yes** → `Task { await viewModel.confirmSocialDM() }`, **No** → `viewModel.dismissSocialDM()`. (Bind visibility to `viewModel.pendingSocialDM != nil` gated on `.active`.)
- [ ] **Step 3: Update existing tests** that assumed the old layout (`CoachDetailComponentsTests`, `CoachDetailViewTests`, `CoachDetailAccessibilityTests`) — fix constructor calls (`CoachDetailHeader(coach:school:)` still valid via defaults; `CoachStatsGrid(insights:)` replaces `CoachStatsGrid(stats:)`), and add/adjust assertions for the new sections. Decide stale-vs-wrong per failing assertion (CLAUDE.md rule) — old assertions referencing removed `stats`-based cards are stale; migrate them to `insights`.
- [ ] **Step 4: Remove dead code** — if nothing else consumes `viewModel.stats`/`CoachStats`/`computeStats()` after the grid moved to `insights`, delete them; otherwise leave. Verify with `grep -rn "\.stats\b\|CoachStats\|computeStats"`.

- [ ] **Step 5: Run the affected suites — expect PASS.**

Run: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/CoachDetailViewModelTests -only-testing:TheRecruitingCompassTests/CoachDetailComponentsTests -only-testing:TheRecruitingCompassTests/CoachDetailViewTests -only-testing:TheRecruitingCompassTests/CoachDetailAccessibilityTests -only-testing:TheRecruitingCompassTests/CoachInsightsTests -only-testing:TheRecruitingCompassTests/CoachTagsValidatorTests -only-testing:TheRecruitingCompassTests/CoachDecodingTests`

- [ ] **Step 6: Commit.**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/CoachDetailView.swift TheRecruitingCompassTests/
git commit -m "feat(coaches): recompose CoachDetailView into boxed Figma sections + social-DM confirm"
```

---

### Task 16: Full gate + PR

**Files:** none (verification).

- [ ] **Step 1: Clean build.** `DEVELOPER_DIR=… xcodebuild build … -quiet` → EXIT 0.
- [ ] **Step 2: SwiftLint** the changed/new files: `DEVELOPER_DIR=… swiftlint lint --config .swiftlint.yml <files>` → no errors (watch `viewbuilder_on_some_view`, line ≤120).
- [ ] **Step 3: Run the affected test classes** (Task 15 Step 5 command) → TEST SUCCEEDED.
- [ ] **Step 4: Push + PR** to `main` via the `ship` skill. PR body documents the three parity deltas (spec §9): social-DM return-confirm vs web fire-on-open; iOS-built analytics gauge/rings (web deferred); edit/delete in header. Note: not device-verified.
- [ ] **Step 5: Watch CI** — Build & Unit Tests must be green (E2E red = known non-blocking flake). Merge after green.

---

## Self-Review

**Spec coverage:** §2 model/requests/validation → Tasks 1,2,14. §3 insights → Tasks 3,4. §4 layout/SectionCard → Tasks 5,15. §5.1 header → Task 6. §5.2 alerts → Task 7. §5.3 stat cards → Task 8. §5.4 channels → Task 9. §5.5 analytics → Task 11. §5.6 tags → Task 12. §5.7 meta → Task 13. §6 social-DM → Tasks 10,15. §8 testing → per-task + Task 16. §9 deltas → Task 16 PR body. All covered.

**Placeholder scan:** No TBD/"handle edge cases"/"similar to". Each code step has real code or exact edit instructions. SwiftUI cards where full styling is described-not-coded (Tasks 8/9/11/13) give exact tokens, values, and view snippets for the non-obvious math (ring trim, bar proportions); remaining layout is standard SwiftUI.

**Type consistency:** `CoachInsights.make(coach:interactions:now:)`, `.daysSinceContact`, `.isOverdue`, `.responseRate`, `.preferredChannel`, `.sent`/`.received`, `.overdueAlert`/`.channelPreferenceAlert` used consistently across Tasks 3/4/7/8/11/15. `pendingSocialDM`/`armSocialDM`/`confirmSocialDM`/`dismissSocialDM` consistent across Tasks 10/15. `CoachTagsValidator.sanitize`/`sanitizeSource` consistent across Tasks 2/12. `SectionCard(label:content:)` consistent across Tasks 5/15. `CoachStatsGrid(insights:)` consistent across Tasks 8/15. Social log uses `InteractionType.directMessage` + `Direction.outbound` (verified enum cases exist).

**One open item flagged for execution:** confirm `Direction` inbound case name (`grep -rn "enum Direction"`) before Task 3/10 — the plan assumes `.inbound`/`.outbound`.
