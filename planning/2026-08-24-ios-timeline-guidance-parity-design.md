# iOS Timeline Guidance Parity — Design Spec

**Date:** 2026-08-24
**Status:** Approved (design shape) — pending spec review → implementation plan
**Author:** Chris + Claude
**Parity target:** web `pages/timeline/index.vue` guidance sidebar → iOS Timeline

---

## Goal

The web Recruiting Timeline has a right-hand guidance sidebar with 5 panels. iOS
Timeline shows only tasks. Bring the 5 panels to iOS at parity.

Web sidebar panels:
1. What Matters Now
2. Upcoming Milestones
3. Recruiting Calendar
4. Common Worries
5. What NOT to Stress About

## Decisions locked (with Chris)

| Decision | Choice |
|---|---|
| Placement | **Segmented control** `Tasks | Guidance` at top of Timeline screen |
| Audience | **All 5 panels visible to everyone** (web parity — no role gating) |
| Calendar | **Rendered on both** Dashboard (existing) **and** Guidance tab (web parity) |

Rejected: inline-below-phase-cards (chosen segmented instead); separate pushed
screen; parent-only gating of the two worry panels.

---

## Architecture

### Screen structure — `RecruitingTimelineView.swift`

Add `@State private var selectedTab: TimelineTab = .tasks` and a segmented
`Picker`. Parent banner + athlete switcher + header stay **above** the picker
(apply to both tabs). Below the picker, switch content:

```
[TimelineParentBanner]          (parent only, existing)
[header title]                  (existing)
[TimelineAthleteSwitcher]       (parent only, existing)
[ Picker: Tasks | Guidance ]    (NEW — .pickerStyle(.segmented))
─────────────────────────────
selectedTab == .tasks     → existing TimelineMainContent (stat pills + phase cards)
selectedTab == .guidance  → NEW TimelineGuidanceView
```

`TimelineTab`: `enum TimelineTab: String, CaseIterable { case tasks, guidance }`.

`TimelineGuidanceView` = `ScrollView` > `LazyVStack(spacing:16)` holding the 5
widgets in web sidebar order. Each widget is an independently collapsible card
(DisclosureGroup or existing collapse pattern), matching web's per-panel toggle.
Default-expanded: What Matters Now (web default); others collapsed; Calendar has
no outer collapse (matches web).

### The 5 widgets

| # | Widget | Source of truth | Build |
|---|---|---|---|
| 1 | `WhatMattersNowWidget` | `fetchWhatMattersNow` endpoint (already server-ranked) | Keep top-5 array in VM (see below); render numbered list of `title` + `whyItMatters` |
| 2 | `UpcomingMilestonesWidget` | `RecruitingCalendar.upcomingMilestones(...)` (exists) | Extract standalone view over existing func → `[CalendarMilestone]` |
| 3 | `RecruitingCalendarWidget` | existing `Features/Dashboard/Components/RecruitingCalendarWidget.swift` | Reuse as-is; pass sport/gender/graduationYear |
| 4 | `CommonWorriesWidget` | NEW Swift port of web `utils/parentWorries.ts` | Static data + phase-filter + accordions |
| 5 | `WhatNotToStressWidget` | NEW Swift port of web `utils/parentReassurance.ts` | Static data + phase-filter + icon/title/message |

---

## Data details

### 1. What Matters Now — VM change, no ranking port

**Key finding:** iOS already calls the server endpoint `fetchWhatMattersNow`,
which returns a **pre-prioritized** `[WhatMattersItem]`. `TimelineViewModel`
currently discards all but `.first` (`currentTask = ...first`,
`TimelineViewModel.swift:110`).

`WhatMattersItem` (`TimelineAPIModels.swift:24-33`) already has:
`taskId, title, whyItMatters (non-optional), category, priority, isRequired`.

**Change:** add `var whatMattersItems: [WhatMattersItem] = []` to the VM; assign
`Array(result.prefix(5))` alongside the existing `currentTask = result.first`.
No on-device ranking — the web `getWhatMattersNow` algorithm runs server-side and
is already reflected in the endpoint order. (Web's Timeline page recomputes
client-side, but the same endpoint exists at `server/api/athlete/what-matters-now.get.ts`;
iOS consuming it is already-correct parity.)

Web widget UX: tapping a priority scrolls to + expands the matching phase card.
Cross-tab equivalent on iOS: switch `selectedTab = .tasks` + expand that phase.
**v1: display-only** (no tap-through) unless trivially cheap — flagged as fast-follow.

### 2. Upcoming Milestones — extract

`RecruitingCalendar.upcomingMilestones(_:sport:division:gender:footballSubdivision:graduationYear:limit:)`
already returns `[CalendarMilestone]` (`RecruitingCalendar.swift:241-262`), today
only reachable inside `RecruitingCalendarWidget`. Build a standalone
`UpcomingMilestonesWidget` calling the same func. `CalendarMilestone`:
`date, title, type (MilestoneType), url?, description?`. Render type-icon + title +
formatted date + description + external-link affordance (open `url` when present).
Empty state: "No upcoming milestones in the next 6 months." (match web copy).

### 3. Recruiting Calendar — reuse

`RecruitingCalendarWidget(sport:gender:graduationYear:)` unchanged. Same athlete
sport/gender/gradYear inputs the Dashboard uses.

### 4 & 5. Static copy port — byte-for-byte

Canonical source (DO NOT paraphrase — copy verbatim):
- `recruiting-compass-web/utils/parentWorries.ts` — 15 entries
- `recruiting-compass-web/utils/parentReassurance.ts` — 8 entries

**`ParentWorry`** (Swift): `id: String, question: String, answer: String,
phases: [TimelinePhase], category: WorryCategory`.
- `phases[]` web strings = `freshman/sophomore/junior/senior` → map directly to
  `TimelinePhase` rawValues.
- `category` values: `recruiting / academics / mental_health / timeline`.
- Filter: entries whose `phases` contains current phase.
- **Sort: by category alphabetical** (`academics, mental_health, recruiting,
  timeline`) — matches web `category.localeCompare`.
- Empty state: "No common worries at this stage."
- Render: DisclosureGroup accordions, `question` = summary, `answer` = body.

**`ReassuranceMessage`** (Swift): `id: String, title: String, message: String,
phases: [TimelinePhase], icon: String` (literal emoji).
- Filter by current phase. **No sort** — preserve array order (matches web).
- Empty state: "No reassurance needed—you're doing great!"
- Render: `icon` + `title` + `message`.

### Phase mapping

`TimelinePhase` rawValues: `freshman/sophomore/junior/senior/committed`
(`TimelinePhase.swift:5-9`). Current phase = `TimelineViewModel.currentPhase`,
sourced from the `/api/athlete/phase` endpoint (not computed on-device).

`committed` has no web worry/reassurance entries (web phases[] only use the 4
grade words). Committed athletes → treat as grade-12 bucket = **filter with
`senior`** for panels 4/5, OR show empty state. **Decision: filter as `senior`**
(committed seniors still benefit from senior-phase guidance). Confirm during
implementation that this matches web behavior for a committed athlete (web
`currentPhase` may itself never return "committed" to these filters — verify).

### Localization

All new static strings (15 worries × question+answer, 8 reassurance ×
title+message, widget headings, empty states) → `Core/Localizable.xcstrings` per
project convention. Emoji icons stay literal (not localized).

---

## Testing

Unit (`TheRecruitingCompassTests/`):
- `ParentWorry` phase-filter: given phase → returns exactly the web-expected
  subset; sort is category-alphabetical.
- `ReassuranceMessage` phase-filter: correct subset, array order preserved.
- **Dataset count guards:** assert 15 worries / 8 reassurance total — a future
  edit can't silently drop parity.
- Per-phase count parity: snapshot the count of worries/reassurance returned for
  each of freshman/sophomore/junior/senior; lock to web's per-phase counts.
- VM: `whatMattersItems` = top-5 of endpoint result; `currentTask` still `.first`.
- Milestone extraction: `UpcomingMilestonesWidget` renders the same
  `upcomingMilestones(...)` output the calendar widget uses.

Accessibility: DisclosureGroups have labels; segmented control values labeled;
external milestone links have hint. Follow existing project a11y conventions.

Build gate: `xcodebuild build` (iPhone 17 sim) exit 0 before done.

---

## Files

**New:**
- `Features/Timeline/Views/TimelineGuidanceView.swift`
- `Features/Timeline/Components/WhatMattersNowWidget.swift`
- `Features/Timeline/Components/UpcomingMilestonesWidget.swift`
- `Features/Timeline/Components/CommonWorriesWidget.swift`
- `Features/Timeline/Components/WhatNotToStressWidget.swift`
- `Features/Timeline/Models/ParentWorry.swift` (data + static array)
- `Features/Timeline/Models/ReassuranceMessage.swift` (data + static array)
- Tests mirroring the above under `TheRecruitingCompassTests/Features/Timeline/`

**Modified:**
- `Features/Timeline/Views/RecruitingTimelineView.swift` (segmented control + tab switch)
- `Features/Timeline/ViewModels/TimelineViewModel.swift` (add `whatMattersItems`)
- `Core/Localizable.xcstrings` (new strings)

**Reused unchanged:**
- `Features/Dashboard/Components/RecruitingCalendarWidget.swift`
- `Core/Utilities/RecruitingCalendar/RecruitingCalendar.swift`

---

## Parity guarantees

- Content of panels 4/5 copied byte-for-byte from web utils; count + per-phase
  guards prevent silent drift.
- What Matters Now consumes the same server endpoint as web → ranking parity for free.
- Calendar + Milestones already share the web-mirrored `RecruitingCalendar` dataset.
- Web-parity check required on any future edit to either platform's worry/
  reassurance copy (platform-parity skill).

## Open items to confirm during implementation

1. Does web `currentPhase` ever surface `committed` to the worry/reassurance
   filters? If yes, confirm `senior`-bucket fallback matches web; if web shows
   empty, match that instead.
2. What Matters Now tap-through (switch to Tasks tab + expand phase) — v1
   display-only; promote to fast-follow if desired.
3. Web milestones panel hardcodes `division = "D1"`; confirm iOS passes the same
   default so milestone sets match.
