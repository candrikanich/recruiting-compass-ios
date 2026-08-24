# Design: Merge Recruiting Calendar + Upcoming Milestones (iOS + Web)

**Date:** 2026-08-24
**Status:** Approved design — ready for implementation plan
**Platforms:** iOS (Swift/SwiftUI) + Web (Nuxt/Vue) — symmetric change
**Classification:** Architectural (cross-platform, shared component restructure)

---

## Problem

"Upcoming Milestones" and "Recruiting Calendar" look like duplicate data. They are
**not** two data sources — both platforms already resolve them from **one shared
registry**. The duplication is a redundant *render*, not redundant data.

- **iOS shared source:** `Core/Utilities/RecruitingCalendar/RecruitingCalendar.swift`
  (`upcomingMilestones(...)` :256, `calendar(...)` :165) + `RecruitingCalendarData.swift`
  (`genericMilestones` :623 — SAT/ACT/FAFSA/eligibility dates; `d1Calendars`/`d2AllSports`/
  `d3Fallback` period sets).
- **Web shared source:** `utils/recruitingCalendar/resolver.ts` (`getUpcomingMilestones` :234,
  `getSportCalendar` :110) + `calendarData.ts` (periods, source, verifiedOn) +
  `ncaaRecruitingCalendar.ts` (`genericMilestones`: SAT/ACT/FAFSA/eligibility).

Both `upcomingMilestones` / `getUpcomingMilestones` already merge the resolved per-sport
calendar's milestones with the generic dates into ONE list — NCAA period markers and
SAT/ACT/FAFSA interleave chronologically already.

**The redundant render:** on the **Timeline** screen, both platforms render the standalone
milestone list *and then* the calendar widget (which has its own upcoming list) back-to-back,
with identical resolver params → the same rows appear twice.

- iOS `Features/Timeline/Views/TimelineGuidanceView.swift`: `UpcomingMilestonesWidget` (:41)
  then `RecruitingCalendarWidget` (:49).
- Web `pages/timeline/index.vue`: `<UpcomingMilestones>` (:160) then `<RecruitingCalendar>` (:165).
- **Dashboard** (both platforms) already renders ONLY the calendar widget — no duplication there.

The only real difference between the two renders: the standalone milestone list has **rich rows**
(emoji icon by milestone type, description line, external-link affordance), while the calendar
widget's upcoming list is **terse** (title + date).

---

## Decisions (locked)

1. **End state:** one merged surface.
2. **Placement:** both Dashboard + Timeline, via ONE shared component (the calendar widget
   is already that shared component on both screens).
3. **Merge shape:** periods header (current-period "Right now" banner + gender / FBS-FCS
   toggles + source citation) → ONE unified rich upcoming list below it.
4. **Standalone milestone component:** keep as an **embedded sub-component** inside the
   calendar widget (reuse, not inline-duplicate).
5. **Dashboard:** keep full periods chrome — only the upcoming rows get richer.

---

## Design

### §1 — Data layer: NO CHANGE
`RecruitingCalendar.upcomingMilestones` (iOS) / `getUpcomingMilestones` (web) and the
registries stay exactly as shipped. Zero risk to the sport-recruiting-calendar arc merged
2026-08-23. The merge is presentation-only.

### §2 — Component shape (per platform)
The calendar widget becomes the single home. Its terse upcoming list is replaced by the
rich-row list component (embedded), so the widget reads: **periods header → unified rich list**.

- **iOS** `Features/Dashboard/Components/RecruitingCalendarWidget.swift`
  - Replace the terse upcoming list (:207–223) with the rich row currently in
    `Features/Timeline/Components/UpcomingMilestonesWidget.swift`.
  - Extract that widget's rich row into a reusable view (e.g. `UpcomingMilestoneRow` or keep
    `UpcomingMilestonesWidget` as an embeddable list view taking `[CalendarMilestone]`) and
    render it inside the calendar widget. `UpcomingMilestonesWidget.swift` survives as the
    embedded sub-component.
- **Web** `components/Dashboard/RecruitingCalendar.vue`
  - Replace the "Next Key Dates" block (:123–160) with `<UpcomingMilestones :milestones="upcomingDates" />`.
  - `components/Timeline/UpcomingMilestones.vue` survives, now embedded inside the calendar widget.

Rich row spec (both platforms — already implemented in the standalone components):
emoji icon by `MilestoneType`, `title`, formatted `date`, optional `description`, external-link
row when `milestone.url` is set.

### §3 — Remove the redundant Timeline render
- **iOS** `TimelineGuidanceView.swift`: delete the `UpcomingMilestonesWidget` render at :41
  (the "📅 Upcoming Milestones" collapsible section). The "📆 Recruiting Calendar" section
  (:49) now carries the rich list.
- **Web** `pages/timeline/index.vue`: delete `<UpcomingMilestones>` at :160 (and its now-unused
  `upcomingMilestones` computed at :352 if nothing else consumes it — verify before removing).
  `<RecruitingCalendar>` at :165 now carries the rich list.
- **Dashboard** (both): unchanged structurally; upcoming rows get richer for free.

### §4 — Compact vs full: minimal
No separate modes (YAGNI). Single row-cap param on the shared list:
- Dashboard: keep current cap (`limit: 5`).
- Timeline: allow more (proposed `8`) since it's the dedicated guidance screen.
iOS widget already has a `showHeader` flag differentiating card-vs-embedded — reuse it; add
only a `maxRows`/`limit` if not already present.

### §5 — Testing
- **Data:** unchanged; existing iOS `RecruitingCalendarWidgetTests` / `RecruitingCalendarTests`
  and web resolver tests still cover it.
- **Add:**
  - Rich row renders icon + description + external-link when `url` present.
  - Timeline no-duplicate assertion: standalone milestone section is gone; milestone rows
    appear exactly once.
  - Dashboard still renders the calendar widget with the (now rich) list.
  - Update/remove any snapshot or view test referencing the standalone Timeline milestones section.

---

## Net change
- **Deleted:** one render call per platform + the terse-list markup inside each calendar widget.
- **Added:** rich list embedded into the shared calendar widget; one row-cap param.
- **Survives:** `UpcomingMilestonesWidget.swift` / `UpcomingMilestones.vue` as embedded
  sub-components. Registry/resolver untouched.

## Parity checklist
- [ ] iOS: rich rows in `RecruitingCalendarWidget`; standalone removed from Timeline; Dashboard intact.
- [ ] Web: rich rows in `RecruitingCalendar.vue`; standalone removed from Timeline; Dashboard intact.
- [ ] Both: milestone rows appear exactly once per screen; period chrome + citation preserved.
- [ ] Row cap: Dashboard 5, Timeline 8 (or agreed values) — identical both platforms.

## Open questions
- Confirm the web `upcomingMilestones` computed at `pages/timeline/index.vue:352` has no other
  consumer before deleting it.
- Timeline row cap value (proposed 8) — confirm during implementation or leave at 5 for exact parity.
