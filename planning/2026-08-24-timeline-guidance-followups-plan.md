# iOS Timeline Guidance Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Five refinements to the just-shipped iOS Timeline Guidance tab: populate real SAT/ACT/FAFSA milestones, make all 5 sections collapsible + equal-width, give Common Worries per-item cards, and make What-Matters-Now items tap through to the task.

**Architecture:** One data port (generic NCAA/testing milestones → iOS calendar data + merge in `upcomingMilestones`). One shared `CollapsibleSection` container that provides uniform card chrome (equal width) + collapse chrome for all 5 guidance sections. Per-item card styling for Common Worries. A phase-level tap-through from What-Matters items into the Tasks tab via `ScrollViewReader`.

**Tech Stack:** Swift, SwiftUI, `@Observable @MainActor` MVVM, XCTest.

**Spec:** this doc (self-contained; follow-up to `planning/2026-08-24-timeline-guidance-parity-design.md`).

## Global Constraints

- Source root (double-nested): `TheRecruitingCompass/TheRecruitingCompass/`; tests: `TheRecruitingCompass/TheRecruitingCompassTests/`.
- Build gate: `xcodebuild build -project TheRecruitingCompass/TheRecruitingCompass.xcodeproj -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet` — exit 0, no new errors, before any "done". Run from worktree root, no `cd`.
- Trust xcodebuild exit code + pass/fail counts, NOT a grep for "TEST SUCCEEDED".
- SourceKit "Cannot find type X in scope" / "No such module XCTest" are stale-index false positives in this repo — ignore; the build is truth.
- All ViewModels `@MainActor`; new `@MainActor` classes need `nonisolated deinit {}`.
- New `.swift` files auto-included (PBXFileSystemSynchronizedRootGroup) — NEVER edit `.xcodeproj`.
- SwiftLint line length ≤ 120 (scoped `// swiftlint:disable/enable line_length` acceptable around verbatim long string literals).
- Milestone copy/dates ported = **byte-for-byte** from web `recruiting-compass-web/utils/ncaaRecruitingCalendar.ts`. Parity is the point.
- New user-facing strings → `String(localized:)`.
- Do NOT commit `Core/SupabaseConfig.generated.swift` (regenerated every build). Use explicit `git add <path>`, never `git add -A`.

---

### Task 1: Port generic milestones (SAT/ACT/NCAA/NAIA/FAFSA/app deadlines)

**Problem:** iOS `RecruitingCalendarData.swift` has only 5 `.signing` milestones (Baseball+Football); every other sport is `milestones: []`. Web merges a sport-agnostic `GENERIC_MILESTONES` list into every athlete's upcoming milestones. iOS never ported it → the Upcoming Milestones widget is near-empty.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/RecruitingCalendar/RecruitingCalendarData.swift` (add a module-level generic list)
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/RecruitingCalendar/RecruitingCalendar.swift` (merge generics in `upcomingMilestones`)
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/RecruitingCalendarGenericMilestonesTests.swift`
- Port source (read verbatim): `recruiting-compass-web/utils/ncaaRecruitingCalendar.ts` — the arrays `SAT_TEST_DATES_2026` (8), `ACT_TEST_DATES_2026` (7), `NCAA_DEADLINES_2026`, `NAIA_DEADLINES_2026`, `COLLEGE_APPLICATION_DEADLINES_2026` (incl. `FAFSA Opens` 2026-10-01). And web `utils/recruitingCalendar/resolver.ts` `GENERIC_MILESTONES` (lines ~204-210) + `getUpcomingMilestones` to confirm HOW generics are merged and filtered.

**Interfaces:**
- Consumes: `CalendarMilestone { date: String; title: String; type: MilestoneType; url: String?; description: String? }`; `MilestoneType { test, deadline, ncaaPeriod = "ncaa-period", application, signing }` (`RecruitingCalendar.swift:37-41`).
- Produces: `RecruitingCalendarData.genericMilestones: [CalendarMilestone]` (static/module-level, all generic entries). `RecruitingCalendar.upcomingMilestones(...)` now returns sport-calendar milestones **merged with** genericMilestones, deduped, sorted ascending, type-bucketed by grad year exactly as today, capped at `limit`.

- [ ] **Step 1: Verify web merge + filter semantics**

Read web `utils/recruitingCalendar/resolver.ts` `getUpcomingMilestones` + `GENERIC_MILESTONES`. Confirm: (a) generics are merged for ALL sports/divisions; (b) whether generics are grade/type-filtered the same way iOS `milestoneTypes(forGraduationYear:currentYear:)` filters. Also inspect the iOS `senior = currentYear + 3` bucket cutoff (`RecruitingCalendar.swift:~273`) against web — if web's senior cutoff differs (e.g. `currentYear + 1`), that's an iOS BUG to fix so SAT/ACT/FAFSA surface for the right grades; if web matches iOS, leave it (parity). Record the finding in your report.

- [ ] **Step 2: Write the failing test**

```swift
import XCTest
@testable import TheRecruitingCompass

final class RecruitingCalendarGenericMilestonesTests: XCTestCase {
    // Generic milestones must surface for a sport whose calendar has no milestones
    // (e.g. a non-baseball/football sport), proving the merge is sport-agnostic.
    func testGenericMilestonesSurfaceForAnySport() {
        let result = RecruitingCalendar.upcomingMilestones(
            "2026-01-01", sport: "soccer", division: "D1",
            gender: "male", graduationYear: nil, limit: 50)
        XCTAssertTrue(result.contains { $0.type == .test && $0.title.contains("SAT") },
                      "SAT test dates should appear for any sport")
        XCTAssertTrue(result.contains { $0.title.contains("FAFSA") },
                      "FAFSA Opens should appear")
    }

    func testGenericMilestoneCountMatchesPort() {
        // Adjust the expected total to the exact count you port (SAT 8 + ACT 7 + NCAA/NAIA + app deadlines).
        XCTAssertEqual(RecruitingCalendarData.genericMilestones.count, EXPECTED_TOTAL)
    }

    func testSATDatesAreRealPortedValues() {
        let sat = RecruitingCalendarData.genericMilestones.filter { $0.title.contains("SAT") }
        XCTAssertEqual(sat.count, 8)
        XCTAssertTrue(sat.contains { $0.date == "2026-10-03" })
    }
}
```
Replace `EXPECTED_TOTAL` with the real count once ported.

- [ ] **Step 3: Run test, verify it fails**

Run: `xcodebuild test -project TheRecruitingCompass/TheRecruitingCompass.xcodeproj -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/RecruitingCalendarGenericMilestonesTests`
Expected: FAIL — `genericMilestones` undefined.

- [ ] **Step 4: Port the data + wire the merge**

In `RecruitingCalendarData.swift`, add `static let genericMilestones: [CalendarMilestone]` transcribing every SAT/ACT/NCAA/NAIA/FAFSA/college-application entry from web `ncaaRecruitingCalendar.ts` verbatim (date/title/type/url/description). Web `division: "ALL"` has no iOS field — drop it (generics apply to all). Map web types: `"test"→.test`, `"application"→.application`, `"deadline"→.deadline`.
In `RecruitingCalendar.upcomingMilestones(...)`, merge `RecruitingCalendarData.genericMilestones` into the candidate list alongside `cal.milestones` BEFORE the existing date-filter/type-bucket/sort/cap. Keep the existing bucket + sort + limit logic unchanged (only widen the input set). If Step 1 found the senior-cutoff is an iOS bug vs web, fix that cutoff here too.

- [ ] **Step 5: Run test, verify pass**

Run: same `-only-testing:...GenericMilestonesTests`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/RecruitingCalendar/RecruitingCalendarData.swift TheRecruitingCompass/TheRecruitingCompass/Core/Utilities/RecruitingCalendar/RecruitingCalendar.swift TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/RecruitingCalendarGenericMilestonesTests.swift
git commit -m "feat(timeline): port generic SAT/ACT/NCAA/FAFSA milestones for parity"
```

---

### Task 2: `CollapsibleSection` — uniform width + per-section collapse for all 5

**Delivers items #2 (collapse) and #3 (equal width) together:** a shared container that owns the card chrome (with `maxWidth: .infinity` → equal width) and the collapse header (title + chevron). The 4 new guidance widgets become content-only; `TimelineGuidanceView` owns collapse state and wraps all 5.

**Files:**
- Create: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/CollapsibleSection.swift`
- Modify (strip own card chrome + header, expose content only): `WhatMattersNowWidget.swift`, `UpcomingMilestonesWidget.swift`, `CommonWorriesWidget.swift`, `WhatNotToStressWidget.swift`
- Modify: `Features/Dashboard/Components/RecruitingCalendarWidget.swift` (add `showHeader: Bool = true`)
- Modify: `Features/Timeline/Views/TimelineGuidanceView.swift` (collapse state + wrap all 5)

**Interfaces:**
- Produces: `struct CollapsibleSection<Content: View>: View { let title: String; let isExpanded: Bool; let onToggle: () -> Void; @ViewBuilder let content: () -> Content }`. Renders a `VStack(alignment: .leading, spacing: 12)`: a header `Button(action: onToggle)` row = `Text(title).font(.headline)` + `Spacer()` + chevron `Image(systemName: isExpanded ? "chevron.up" : "chevron.down")`, header `.accessibilityAddTraits(.isHeader)`; then `if isExpanded { content() }`. Container chrome: `.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.Surface.card).clipShape(.rect(cornerRadius: 12)).brandShadowSm()`. The `maxWidth: .infinity` is what makes all sections equal width.
- The 4 new widgets: remove `.padding()/.background/.clipShape/.brandShadowSm()` and their title+subtitle header from the root; the widget body becomes just the inner content (subtitle line MAY stay as the first content row). Keep their `init` params otherwise (e.g. `phase`, `items`).
- `RecruitingCalendarWidget`: add `showHeader: Bool = true`; when false, suppress its internal "Recruiting Calendar" title row (so the CollapsibleSection title isn't duplicated). Default true keeps the Dashboard call site unchanged.

- [ ] **Step 1: Build `CollapsibleSection`**

Implement per the interface above. Emoji lives in the `title` string passed by the caller (e.g. "❓ Common Worries").

- [ ] **Step 2: Strip chrome+header from the 4 new widgets**

For each of WhatMattersNowWidget / UpcomingMilestonesWidget / CommonWorriesWidget / WhatNotToStressWidget: remove the outer card modifiers (`.padding()/.background(Color.Surface.card)/.clipShape/.brandShadowSm()`) and the emoji-title `Text(...).font(.headline)` header. Keep the subtitle + the item list as the widget's body (a plain `VStack(alignment:.leading, spacing:...)`). The widget now renders ONLY its content; the section wrapper supplies chrome + title.

- [ ] **Step 3: Add `showHeader` to RecruitingCalendarWidget**

Add `var showHeader: Bool = true`. Wrap its internal title row in `if showHeader { ... }`. Verify the Dashboard call site (`DashboardChartsAndDataSection.swift`) still compiles (uses the default true).

- [ ] **Step 4: Wire collapse state in TimelineGuidanceView**

Add 5 `@State private var` expand flags: `whatMattersExpanded = true`, `milestonesExpanded = false`, `calendarExpanded = false`, `worriesExpanded = false`, `stressExpanded = false` (web defaults: What Matters open, rest collapsed). Wrap each widget:
```swift
CollapsibleSection(title: String(localized: "⚡ What Matters Right Now"),
                   isExpanded: whatMattersExpanded,
                   onToggle: { whatMattersExpanded.toggle() }) {
    WhatMattersNowWidget(items: viewModel.whatMattersItems,
                         phaseLabel: viewModel.currentPhase.gradeLabel)
}
```
Do the same for the other 4 (Upcoming Milestones, Recruiting Calendar with `showHeader: false`, Common Worries, What NOT to Stress) in the same web-sidebar order.

- [ ] **Step 5: Build verify**

Run the build gate. Expected exit 0. Visually reason: all 5 sections now share `CollapsibleSection`'s `maxWidth: .infinity` chrome → equal width; each collapses independently; What Matters starts open, rest collapsed.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/CollapsibleSection.swift TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/WhatMattersNowWidget.swift TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/UpcomingMilestonesWidget.swift TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/CommonWorriesWidget.swift TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/WhatNotToStressWidget.swift TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/RecruitingCalendarWidget.swift TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/TimelineGuidanceView.swift
git commit -m "feat(timeline): collapsible equal-width guidance sections via CollapsibleSection"
```

---

### Task 3: Common Worries — per-item cards (kill the blob)

**Problem:** worries render as bare stacked `DisclosureGroup`s (a visual blob). Web gives each its own bordered card.

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/CommonWorriesWidget.swift` (now content-only after Task 2)

- [ ] **Step 1: Card each worry**

Wrap each `DisclosureGroup` (one per `ParentWorry`) in its own card: `.padding(12).background(Color.Surface.muted).clipShape(.rect(cornerRadius: 8))` (mirror the milestone-row treatment in `UpcomingMilestonesWidget`). Keep the `ForEach(worries)`; each iteration renders one carded DisclosureGroup (label = question, content = answer). Preserve `String(localized:)` and the empty-state text. Result: each worry reads as its own item, not a blob.

- [ ] **Step 2: Build verify** — build gate, exit 0.

- [ ] **Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/CommonWorriesWidget.swift
git commit -m "feat(timeline): render each Common Worry as its own card"
```

---

### Task 4: What-Matters-Now → tap through to the task (phase-level)

**Delivers item #1 at phase level:** tap an item → switch to Tasks tab → expand that grade's phase card → scroll to it. (No individual task-row open / highlight — out of scope by decision.)

**Files:**
- Modify: `Features/Timeline/Components/WhatMattersNowWidget.swift` (add tap callback)
- Modify: `Features/Timeline/Views/TimelineGuidanceView.swift` (thread the callback through)
- Modify: `Features/Timeline/Views/RecruitingTimelineView.swift` (handle tap: tab-switch + expand + scroll; add `ScrollViewReader` + `.id` on phase cards)

**Interfaces:**
- Consumes: `WhatMattersItem.taskId`; `TimelineViewModel.tasksByGrade: [Int: [TaskWithStatus]]` (for taskId→gradeLevel lookup); `TimelineViewModel.setExpandedPhase(grade:)` (`TimelineViewModel.swift:145`); `@State selectedTab` (`RecruitingTimelineView.swift:21`); `TaskWithStatus.gradeLevel`.
- Produces: `WhatMattersNowWidget` gains `let onSelectTask: (String) -> Void` (taskId). `TimelineGuidanceView` gains a matching `let onSelectTask: (String) -> Void` passed to the What-Matters section. `RecruitingTimelineView` provides the handler.

- [ ] **Step 1: Add the tap callback to the widget**

`WhatMattersNowWidget` gains `let onSelectTask: (String) -> Void`. Make each numbered row a `Button(action: { onSelectTask(item.taskId) })` (plain button style, keep the current row layout as the label). Keep it display-identical otherwise.

- [ ] **Step 2: Thread through TimelineGuidanceView**

`TimelineGuidanceView` gains `let onSelectTask: (String) -> Void`; pass it into `WhatMattersNowWidget(onSelectTask:)`.

- [ ] **Step 3: Handle it in RecruitingTimelineView + add scroll anchors**

- Wrap the Tasks-tab scroll content in a `ScrollViewReader { proxy in ... }` and add `.id("phase-\(grade)")` to each `PhaseCard` in `TimelineMainContent`'s `ForEach(phaseOrder)`.
- Implement the handler: given `taskId`, look up its `gradeLevel` via `viewModel.tasksByGrade` (find the grade whose array contains a task with `id == taskId`); set `selectedTab = .tasks`; call `viewModel.setExpandedPhase(grade: gradeLevel)`; then `proxy.scrollTo("phase-\(gradeLevel)", anchor: .top)` (wrap the scroll in a tiny `DispatchQueue.main.asyncAfter(deadline: .now() + 0.35)` or `withAnimation` after the tab switch so the Tasks view is laid out — mirror web's 350ms expand-then-scroll).
- Pass this handler into `TimelineGuidanceView(onSelectTask:)`.
- If `ScrollViewReader` needs to reach across the segmented switch, ensure the reader wraps the content that includes both tabs, or scope it to the Tasks-tab branch and trigger scroll after `selectedTab` flips (a `.onChange(of: selectedTab)` that performs the pending scroll is acceptable if a direct call races layout).

- [ ] **Step 4: Build verify** — build gate, exit 0.

- [ ] **Step 5: Manual sim note (report only)**

Note in the report that on-device verification is needed for: tapping a What-Matters item switches to Tasks, expands the right grade, and scrolls to it. (Not blocking; controller tracks device QA separately.)

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/WhatMattersNowWidget.swift TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/TimelineGuidanceView.swift TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/RecruitingTimelineView.swift
git commit -m "feat(timeline): tap What-Matters item to open its task in the Tasks tab"
```

---

## Self-Review

**Spec coverage:**
- #4 real SAT/ACT/FAFSA milestones → Task 1. ✅
- #3 equal width → folded into Task 2 (`CollapsibleSection` `maxWidth: .infinity`). ✅
- #2 per-section collapse (all 5, web defaults) → Task 2. ✅
- #5 Common Worries per-item cards → Task 3. ✅
- #1 What-Matters tap-through (phase-level) → Task 4. ✅

**Ordering rationale:** Task 1 is independent (calendar files). Task 2 refactors the 4 widgets to content-only + builds the section system (subsumes width). Task 3 styles the (now content-only) CommonWorriesWidget. Task 4 adds the tap callback to the (now content-only) WhatMattersNowWidget. Tasks 3 and 4 both run after Task 2 so they edit the post-refactor widget shape — no rework.

**Placeholder scan:** Task 1's `EXPECTED_TOTAL` and the SAT-count are resolved during the port (the web file is the byte-source, count-guarded). No other placeholders.

**Type consistency:** `CollapsibleSection` signature, `genericMilestones`, `onSelectTask: (String) -> Void`, `showHeader: Bool = true`, `setExpandedPhase(grade:)`, `tasksByGrade`, `.id("phase-\(grade)")` used consistently across tasks.

**Open items to confirm during implementation:**
1. Web senior-bucket cutoff vs iOS `currentYear + 3` — fix only if web differs (Task 1 Step 1).
2. `ScrollViewReader` across the tab switch may need an `.onChange(of: selectedTab)` deferred scroll if a direct `scrollTo` races layout (Task 4 Step 3).
3. Whether the What-NOT-to-Stress items also read as a blob — NOT in scope (only Common Worries was requested); leave unless trivially consistent with Task 3.
