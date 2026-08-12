# "Visited" Stat Card → real visits (both apps)

**Date:** 2026-08-12
**Status:** approved, building
**Repos:** recruiting-compass-ios + recruiting-compass-web

## Problem
"Visited" card counts `status ∈ {official_visit_scheduled, official_visit_invited}`.
Both wrong signals: *invited* = not scheduled; *scheduled* = future = hasn't happened.
Also drops schools advanced to offer_received/committed (who surely visited).
Web uses the identical filter — so this is a shared product-definition bug, fixed on both.

## Definition (identical intent both apps)
A school is **visited** if EITHER:
- has an interaction of a **visit type**, OR
- has a **past-dated visit event** (`official_visit`/`unofficial_visit`, `start_date <= now`).

**Visit interaction types:** `in_person_visit`, `official_visit`, `unofficial_visit`.
- `virtual_meeting` EXCLUDED — not a campus visit (card is literally "Visited").
- iOS `InteractionType` only has `in_person_visit`; official/unofficial visits arrive
  as iOS **Events**. Web has all three as interaction types AND events. Same rule string
  works on both — iOS just never has official/unofficial *interaction* rows.

## Behavior change (accepted)
Users who only bumped a school's status (no logged interaction/event) lose that school
from Visited. Correct, but visible.

## iOS
File: `Features/Schools/ViewModels/SchoolsListViewModel.swift`
- Inject `InteractionsManaging` + `EventsManaging` (default `*ServiceImpl(supabaseManager: .shared)`).
- Add `private(set) var visitedSchoolIds: Set<String> = []`.
- `loadSchools()`: after schools load, `async let` bulk
  `interactionsService.fetchInteractions(familyUnitId:)` +
  `eventsService.fetchEvents(userId: selectedAthlete.userId)`. Each in own try/catch —
  visit signal must never block the schools list; degrade to what succeeds.
- Build `visitedSchoolIds`: interactions where `type == .inPersonVisit` → schoolId;
  events where `type ∈ {official_visit, unofficial_visit}` AND `startDate <= now` → schoolId.
- `analytics.visitedCount = allSchools.filter { visitedSchoolIds.contains($0.id) }.count`.
- Date parse helper: ISO8601 (frac + plain) then `yyyy-MM-dd`.

## Web
Files: `composables/useSchoolStats.ts`, `pages/schools/index.vue`
- `useSchoolStats(schools, interactions, events)` — new params (refs).
- Build `Set<school_id>` once inside computed (O(n+m)):
  - interaction `school_id` where `type ∈ VISIT_INTERACTION_TYPES`
    (`in_person_visit`,`official_visit`,`unofficial_visit`).
  - event `school_id` where `type ∈ {official_visit,unofficial_visit}` AND
    `new Date(start_date) <= new Date()`.
- Visited tile value = `schools.filter(s => visitedIds.has(s.id)).length`.
- `pages/schools/index.vue`: add `useEvents` + `fetchEvents({})` to `onMounted` Promise.all;
  pass `allInteractions` + events ref into `useSchoolStats` call (`:269`).

## Tests
- iOS: VM test — schools with visit interaction / past event counted; future event + status-only NOT.
- Web: useSchoolStats unit — same cases.
