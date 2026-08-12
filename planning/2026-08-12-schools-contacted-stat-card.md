# Schools "Contacted" Stat Card (4th widget)

**Date:** 2026-08-12
**Status:** SHIPPED (built, EXIT 0)

## Goal
Fill empty 4th slot in Schools page stat-card row. 4 cards → clean 2×2 grid.

## Decision
"Contacted" — web parity. Offers rejected (too sparse early: most users 0–1).

## Definition (exact web parity)
Web `composables/useSchoolStats.ts:32-38`: `Contacted = schools.filter(s => s.status === "contacted").length`.
Single status only (NOT a set). iOS `SchoolStatus.contacted` rawValue `contacted`.

Derived from `school.status` already loaded — no new fetch.

## Changes
1. `Features/Schools/Models/SchoolAnalytics.swift` — add `contactedCount: Int`
2. `Features/Schools/ViewModels/SchoolsListViewModel.swift` (analytics) —
   `contactedCount: allSchools.filter { $0.status == SchoolStatus.contacted.rawValue }.count`
3. `Features/Schools/Components/SchoolAnalyticsCards.swift` — 4th `AnalyticsCard`,
   title "Contacted", icon `bubble.left.and.bubble.right.fill`, purple (web = purple/chat-bubble).

## Known adjacent bug (NOT fixed here)
"Visited" card counts only `officialVisitScheduled` + `officialVisitInvited` — no unofficial/completed-visit statuses. Widen when next touching row.
