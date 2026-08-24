# Merge Recruiting Calendar + Upcoming Milestones — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the duplicate recruiting-milestone render on the Timeline screen by folding the rich milestone rows into the single shared Recruiting Calendar widget, on iOS and web.

**Architecture:** The milestone data is ALREADY unified — both platforms resolve it from one registry (`RecruitingCalendar` / `utils/recruitingCalendar`). Only the *render* is duplicated: on Timeline, a standalone milestone list renders immediately before the calendar widget, which has its own milestone list. The fix keeps the standalone milestone component as an embedded sub-component inside the calendar widget, and deletes the standalone Timeline render. Data layer untouched.

**Tech Stack:** iOS SwiftUI (Xcode 26.5, iPhone 17 sim); Web Nuxt/Vue 3 + Vitest.

**Spec:** `planning/2026-08-24-merge-calendar-milestones-design.md`

## Global Constraints

- **Canonical merged row (both platforms), from spec §2:** emoji icon by milestone type, `title`, formatted `date`, optional `description`, external-link affordance when `url` is set. NO countdown / urgency styling.
- **Consequence — web regression by design:** web's calendar rows currently show a countdown ("3 days"/"Tomorrow") and an urgent-red border (`getCountdown`, `isWithin30Days`). The canonical row drops both, on Dashboard AND Timeline, for iOS↔web parity and a single row source. Do not re-add unless the plan owner reverses this.
- **Data layer is frozen:** do not modify `RecruitingCalendar.swift`, `RecruitingCalendarData.swift`, `utils/recruitingCalendar/*`, or `utils/ncaaRecruitingCalendar.ts`. Presentation only.
- **iOS paths are double-nested:** `TheRecruitingCompass/TheRecruitingCompass/…`. Run `xcodebuild` from `TheRecruitingCompass/`.
- **Web repo is a separate checkout:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web`. iOS repo: `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios`.
- **Parity gate:** the feature must land on BOTH platforms before "done."

## File Structure

- iOS `Features/Timeline/Components/UpcomingMilestonesWidget.swift` — becomes presentational: takes `milestones: [CalendarMilestone]`, renders rich rows + empty copy. Loses its own data fetch + subheadline.
- iOS `Features/Dashboard/Components/RecruitingCalendarWidget.swift` — its terse "Upcoming" list is replaced by `UpcomingMilestonesWidget(milestones:)`.
- iOS `Features/Timeline/Views/TimelineGuidanceView.swift` — drops the standalone "📅 Upcoming Milestones" section.
- Web `components/Timeline/UpcomingMilestones.vue` — gains a `bare` prop (list-only, no card/header).
- Web `components/Dashboard/RecruitingCalendar.vue` — its "Next Key Dates" block is replaced by `<UpcomingMilestones :milestones bare />`.
- Web `pages/timeline/index.vue` — drops the standalone `<UpcomingMilestones>` + its now-dead computed/state/imports.

---

## Task 1: iOS — make `UpcomingMilestonesWidget` presentational and embed it in the calendar widget

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/UpcomingMilestonesWidget.swift`
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/RecruitingCalendarWidget.swift:207-223`

**Interfaces:**
- Produces: `UpcomingMilestonesWidget(milestones: [CalendarMilestone])` — presentational, no data fetch.

- [ ] **Step 1: Check for existing callers/tests of the old initializer**

Run (both from repo root):
```bash
grep -rn "UpcomingMilestonesWidget(" TheRecruitingCompass/TheRecruitingCompass TheRecruitingCompass/TheRecruitingCompassTests
```
Expected callers to update: `TimelineGuidanceView.swift:41` (removed in Task 2), the `#Preview` in the widget itself. Note any test references for update in this task.

- [ ] **Step 2: Refactor `UpcomingMilestonesWidget` to presentational**

Replace the property block and the `milestones` computed (lines 11-45) so the widget takes milestones directly and drops the date-fetch formatter/`todayISO`/`milestones` computed. Keep `displayFormatter`, the row builders, `formattedDate`, and `icon`. New top of struct:

```swift
struct UpcomingMilestonesWidget: View {
  let milestones: [CalendarMilestone]

  private static let displayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private static let isoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
```

Update `formattedDate` to use `Self.isoFormatter` for parsing:

```swift
  private func formattedDate(_ dateISO: String) -> String {
    guard let date = Self.isoFormatter.date(from: dateISO) else { return dateISO }
    return Self.displayFormatter.string(from: date)
  }
```

Replace `body` (lines 47-63) — drop the "Important dates…" subheadline (the calendar widget supplies the "Upcoming" caption); keep the empty copy + rows:

```swift
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if milestones.isEmpty {
        Text(String(localized: "No upcoming milestones in the next 6 months."))
          .font(.subheadline)
          .foregroundStyle(Color.secondaryText)
      } else {
        ForEach(milestones, id: \.date) { milestone in
          milestoneRow(for: milestone)
        }
      }
    }
  }
```

Update the `#Preview` (lines 127-130) to the new initializer:

```swift
#Preview {
  UpcomingMilestonesWidget(milestones: RecruitingCalendar.upcomingMilestones(
    "2026-08-24", sport: "Baseball", division: "D1", gender: "male", graduationYear: nil
  ))
  .padding()
}
```

- [ ] **Step 3: Embed it in `RecruitingCalendarWidget`**

In `RecruitingCalendarWidget.swift`, replace the "Upcoming" block (lines 207-223) with a version that always shows the caption + the rich sub-component (the sub-component owns the empty state):

```swift
      VStack(alignment: .leading, spacing: 6) {
        Text("Upcoming")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
        UpcomingMilestonesWidget(milestones: upcomingMilestones)
      }
```

- [ ] **Step 4: Build**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```
Expected: exit 0, no new errors.

- [ ] **Step 5: Run the calendar-widget tests**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests/RecruitingCalendarWidgetTests -quiet
```
Expected: exit 0. If any test constructed `UpcomingMilestonesWidget(sport:…)`, update it to `UpcomingMilestonesWidget(milestones:)` (found in Step 1) and re-run.

- [ ] **Step 6: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Components/UpcomingMilestonesWidget.swift TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Components/RecruitingCalendarWidget.swift
git commit -m "refactor(ios): embed rich milestone rows in RecruitingCalendarWidget"
```

---

## Task 2: iOS — remove the standalone milestones section from Timeline Guidance

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/TimelineGuidanceView.swift:16,36-42`

**Interfaces:**
- Consumes: `RecruitingCalendarWidget` (now carries the rich list, from Task 1).

- [ ] **Step 1: Delete the milestones state + section**

Remove the state var (line 16):
```swift
  @State private var milestonesExpanded = false
```
Remove the entire "📅 Upcoming Milestones" `CollapsibleSection` block (lines 36-42), so `⚡ What Matters Right Now` is followed directly by `📆 Recruiting Calendar`.

- [ ] **Step 2: Build**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
```
Expected: exit 0, no `milestonesExpanded` / `UpcomingMilestonesWidget` unresolved errors.

- [ ] **Step 3: Manual sim check**

Launch the app → Timeline → Guidance tab. Verify: no standalone "📅 Upcoming Milestones" section; the "📆 Recruiting Calendar" section shows current period + toggles + rich upcoming rows (icons/description/link); milestone rows appear exactly once.

- [ ] **Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Features/Timeline/Views/TimelineGuidanceView.swift
git commit -m "refactor(ios): drop duplicate milestones section from Timeline Guidance"
```

---

## Task 3: Web — add `bare` mode to `UpcomingMilestones.vue` and embed it in `RecruitingCalendar.vue`

**Files:**
- Modify: `components/Timeline/UpcomingMilestones.vue`
- Modify: `components/Dashboard/RecruitingCalendar.vue:122-160,315-337`
- Test: `test/components/RecruitingCalendar.*` (create if none exists — check first)

Work in `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web`.

**Interfaces:**
- Produces: `<UpcomingMilestones :milestones="Milestone[]" bare />` — renders the `<a>` row list only, no outer card/header/subtitle.

- [ ] **Step 1: Locate any existing RecruitingCalendar test**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
grep -rln "RecruitingCalendar" test/ 2>/dev/null; ls test/components 2>/dev/null | grep -i calendar
```
If a test file exists, extend it in Step 5; otherwise create `test/components/RecruitingCalendar.merge.test.ts`.

- [ ] **Step 2: Add `bare` prop to `UpcomingMilestones.vue`**

Add `bare?: boolean` to `Props` and default it false:
```ts
interface Props {
  milestones: Milestone[];
  collapsed?: boolean;
  bare?: boolean;
}

withDefaults(defineProps<Props>(), {
  collapsed: false,
  bare: false,
});
```
Wrap the outer card + header button so `bare` renders only the row list. Restructure `<template>` to:
```vue
<template>
  <div v-if="bare" class="space-y-2">
    <div v-if="milestones.length === 0" class="py-4 text-center text-sm text-slate-500">
      No upcoming milestones in the next 6 months.
    </div>
    <a
      v-for="milestone in milestones"
      :key="`${milestone.date}-${milestone.title}`"
      :href="milestone.url"
      target="_blank"
      rel="noopener"
      class="group flex cursor-pointer items-start gap-3 rounded-lg border border-slate-200 bg-slate-50 p-3 transition hover:border-slate-300 hover:bg-slate-100"
    >
      <div class="shrink-0"><div class="text-2xl">{{ getMilestoneIcon(milestone.type) }}</div></div>
      <div class="min-w-0 flex-1">
        <div class="font-medium text-slate-900 group-hover:text-slate-950">{{ milestone.title }}</div>
        <div class="mt-0.5 text-xs text-slate-500">{{ formatDate(milestone.date) }}</div>
        <div v-if="milestone.description" class="mt-1 text-xs text-slate-600">{{ milestone.description }}</div>
      </div>
      <div v-if="milestone.url" class="shrink-0 text-slate-400 transition group-hover:text-slate-600">↗</div>
    </a>
  </div>

  <div v-else class="rounded-2xl border border-slate-200 bg-white p-6 shadow-xs">
    <!-- existing card + header button + list, unchanged -->
  </div>
</template>
```
Keep the existing non-bare card markup verbatim inside the `v-else` branch (the current lines 3-76 body). The row list markup is intentionally duplicated between branches to avoid a fragile shared partial; both render identical rows.

- [ ] **Step 3: Swap `RecruitingCalendar.vue` to raw milestones + embed the sub-component**

Change `upcomingDates` (lines 315-337) to return raw `Milestone[]` (drop the `.map` to `RecruitingDate`):
```ts
const upcomingMilestones = computed(() =>
  getUpcomingMilestones({
    sport: props.sport,
    division: props.division,
    graduationYear: props.graduationYear,
    limit: 5,
    opts: resolverOpts.value,
    currentDate: today,
  }),
);
```
Delete the now-dead helpers/types used only by the old mapping and template block: `RecruitingDate` interface, `getCountdown`, `isWithin30Days`, `formatDate`, and the `getMilestoneTypeIcon` import (now used inside `UpcomingMilestones.vue`). Verify each is unreferenced elsewhere in the file before deleting.

Replace the "Next Key Dates" template block (lines 122-160) with:
```vue
    <!-- Next Key Dates -->
    <UpcomingMilestones :milestones="upcomingMilestones" bare />
```
Add the import to the `<script setup>` block:
```ts
import UpcomingMilestones from "~/components/Timeline/UpcomingMilestones.vue";
```

- [ ] **Step 4: Write the failing test**

In the test file from Step 1:
```ts
import { mount } from "@vue/test-utils";
import { describe, it, expect } from "vitest";
import RecruitingCalendar from "~/components/Dashboard/RecruitingCalendar.vue";

describe("RecruitingCalendar merged milestones", () => {
  it("renders milestone rows via embedded UpcomingMilestones with external links", () => {
    const wrapper = mount(RecruitingCalendar, {
      props: { sport: "Baseball", gender: "male", graduationYear: 2028, now: new Date("2026-09-01") },
    });
    const links = wrapper.findAll('a[target="_blank"][rel="noopener"]');
    // At least one milestone row rendered as an external link (SAT/ACT/etc. carry urls).
    expect(links.length).toBeGreaterThan(0);
    // No countdown pill markup remains.
    expect(wrapper.html()).not.toContain("Tomorrow");
  });
});
```

- [ ] **Step 5: Run the test to verify it fails, then passes**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx vitest run test/components/RecruitingCalendar.merge.test.ts
```
Expected before Step 2-3 wiring: FAIL. After: PASS. If the mount needs stubs (auto-imports), follow the pattern in a neighboring `test/components/*` file.

- [ ] **Step 6: Type-check**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx nuxi typecheck 2>&1 | grep -v "unimport" || true
```
Expected: no new errors in `RecruitingCalendar.vue` / `UpcomingMilestones.vue`.

- [ ] **Step 7: Commit**

```bash
git add components/Dashboard/RecruitingCalendar.vue components/Timeline/UpcomingMilestones.vue test/components/RecruitingCalendar.merge.test.ts
git commit -m "refactor(web): embed rich milestone rows in RecruitingCalendar widget"
```

---

## Task 4: Web — remove the standalone `<UpcomingMilestones>` from the Timeline page

**Files:**
- Modify: `pages/timeline/index.vue:160-164,230,236,278,352-361`

**Interfaces:**
- Consumes: `RecruitingCalendar` (now carries the rich list, from Task 3).

- [ ] **Step 1: Delete the standalone render + its dead bindings**

- Remove the `<UpcomingMilestones … />` element (lines 160-164) so `WhatMattersNow` is followed directly by `<RecruitingCalendar>`.
- Remove the import `import UpcomingMilestones from "~/components/Timeline/UpcomingMilestones.vue";` (line 230).
- Remove the `milestonesCollapsed` ref (line 278).
- Remove the `upcomingMilestones` computed (lines 352-361).
- Update the recruitingCalendar import (line 236): drop `getUpcomingMilestones`, keep `NO_SPORT_FALLBACK` and `AppSport`:
```ts
import { NO_SPORT_FALLBACK, type AppSport } from "~/utils/recruitingCalendar";
```
Verify `getUpcomingMilestones` has no other use in the file before removing.

- [ ] **Step 2: Write/adjust the Timeline page test for no-duplicate**

Check for an existing timeline page test:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
grep -rln "timeline" test/ 2>/dev/null
```
Add (or extend) an assertion that the guidance sidebar contains exactly one recruiting-milestone list — the `data-testid="guidance-header"` from the standalone `UpcomingMilestones` card is gone, and `RecruitingCalendar` is present:
```ts
it("shows the calendar without a separate milestones card", () => {
  // mount the timeline page (follow the existing page-test harness in this repo)
  expect(wrapper.find('[data-testid="guidance-header"]').exists()).toBe(false);
  expect(wrapper.findComponent(RecruitingCalendar).exists()).toBe(true);
});
```
If the repo has no page-level test harness for `pages/timeline/index.vue`, skip the automated test and rely on Step 3 + the browser check; note the skip in the commit body.

- [ ] **Step 3: Type-check + run affected tests**

Run:
```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx nuxi typecheck 2>&1 | grep -v "unimport" || true
npx vitest run test/components/RecruitingCalendar.merge.test.ts
```
Expected: no new type errors; test PASS.

- [ ] **Step 4: Browser check**

Run the web app, open `/timeline`. Verify: guidance sidebar has no standalone "Upcoming Milestones" card; the Recruiting Calendar card shows current period + toggles + the rich milestone rows (icon/title/date/description/↗ link); milestone rows appear exactly once. Open `/dashboard` and confirm the calendar card still renders its rows (now without countdown).

- [ ] **Step 5: Commit**

```bash
git add pages/timeline/index.vue test/
git commit -m "refactor(web): drop duplicate milestones card from Timeline page"
```

---

## Self-Review

**Spec coverage:**
- §1 data layer no-change → Global Constraints freeze the registries. ✅
- §2 rich rows embedded via kept sub-component → Task 1 (iOS), Task 3 (web). ✅
- §3 remove redundant Timeline render → Task 2 (iOS), Task 4 (web). ✅
- §4 row cap → both platforms keep `limit: 5` (iOS `upcomingMilestones` computed already unbounded per registry cap; web passes `limit: 5`). Timeline-vs-Dashboard cap left at parity 5 — the proposed Timeline bump to 8 is dropped for exact parity (noted in Open Questions). ✅
- §5 testing → Task 1 Step 5, Task 3 Steps 4-5, Task 4 Step 2. iOS SwiftUI view rendering is build-+-manual verified (project's test suite is pure-function; no view-render harness). ✅

**Placeholder scan:** every code step carries real code; commands are exact. iOS view-render has no unit assertion by project convention — called out, not hidden.

**Type consistency:** `UpcomingMilestonesWidget(milestones:)` used identically in Task 1 Steps 2-3. Web `upcomingMilestones` (raw `Milestone[]`) consumed by `<UpcomingMilestones :milestones bare />` in Task 3.

## Open Questions
- **Timeline row cap:** kept at 5 for exact iOS↔web parity (spec §4 proposed 8). Bump both to 8 if the plan owner prefers the denser Timeline list.
- **Web countdown/urgency removal:** intentional per Global Constraints. Confirm acceptable, or Task 3 keeps `RecruitingCalendar`'s own rich rows (with countdown) and instead just adds the external-link affordance — at the cost of not reusing `UpcomingMilestones.vue`.
- **iOS test coverage of the embedded row:** none added (SwiftUI view render). If a `ViewInspector` harness is later added, assert icon/description/link presence.
