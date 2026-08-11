# Coaches Needing Follow-up widget (iOS) — Design

**Date:** 2026-08-11
**Status:** Approved (design)
**Goal:** Bring the web dashboard's "Coaches Needing Follow-up" widget to the iOS dashboard, at feature parity, reusing existing iOS infrastructure.

## Context

The user observed the web dashboard has widgets iOS lacks and named two: **Upcoming Events** and **Coaches Needing Follow-up**.

Investigation findings:

- **Upcoming Events already exists on iOS** (`Features/Dashboard/Components/UpcomingEventsWidget.swift`), fed by `DashboardViewModel.events`, gated `visibility.eventsSummary && !events.isEmpty` (`DashboardChartsAndDataSection.swift:21`). The user doesn't see it because `events` is empty on their account — a data question, **out of scope** here.
- **Coaches Needing Follow-up does NOT exist on iOS.** This spec covers building it.

Two items explicitly **out of scope**:
1. Why Upcoming Events is empty on the user's account (data/fetch question).
2. Latent bug: `UpcomingEventsWidget` sorts `startDate` ascending but never filters future-only, so it can show past events (web filters `start_date >= today`).

## Web reference

`recruiting-compass-web/components/Dashboard/CoachFollowupWidget.vue`:
- Self-fetches all coaches + schools.
- **Needs-followup rule (`:129-152`):** coach needs follow-up if `last_contact_date` is null/missing OR older than **14 days** ago. Sorted oldest-contact-first; never-contacted ranked first.
- Rows (first 5): `first_name last_name`, school name, days-since string ("Never contacted" / "Today" / "N days ago").
- Actions: Email (if email), Text (if phone), View Profile → `/coaches/{id}`, "View all N coaches" when >5.
- Empty state: "🎉 All caught up! / No coaches need immediate follow-up".

## iOS building blocks (all exist — reused, no new service methods)

- **`Coach` model** (`Features/Dashboard/Models/Coach.swift`): has `firstName`, `lastName`, `email?`, `phone?`, `schoolId`, `lastContactDate?`, computed `fullName`, `lastContactDateParsed: Date?`.
- **`DashboardManaging`** already exposes `fetchSchools(familyUnitId:)` (`:5`) and `fetchCoaches(schoolIds:)` (`:6`). Coaches are always reached via schools: `fetchSchools → schoolIds → fetchCoaches`.
- **`DashboardViewModel`** already holds `familyManager.familyUnitId` and `currentFamilyUnitId` (`:96`), and fans out concurrent fetches in `fetchDashboardData()`.
- **School name lookup:** `Shared/Utilities/EntityNameLookup.swift` — `schoolNameMap(from:)`, `schoolName(for:in:)`.
- **Communication system:** `QuickCommunicationView` (in-app `MFMailComposeViewController` / `MFMessageComposeViewController`, falls back to `mailto:`/`sms:`, and **auto-logs the interaction** via `logSend`). URL builders in `CommunicationType.swift:50-63`.
- **Coach detail:** `CoachDetailView(coachId:allCoaches:allSchools:)`; route enum `CoachDestination.detail(String)`.
- **Widget visibility:** `Features/Preferences/Models/WidgetVisibility.swift` (pattern: `eventsSummary` flag, default `true`, with a toggle row in `DashboardCustomizationView.swift:126`).

No tab-switch infrastructure exists — cross-feature navigation from the dashboard uses sheets.

## Design

### 1. Data (DashboardViewModel)

Add two stored properties:
- `var coachesNeedingFollowup: [Coach] = []`
- `var allSchools: [School] = []`

Add a `fetchCoachesFollowup()` step to the concurrent fan-out in `fetchDashboardData()`:
1. `let schools = try await dashboardService.fetchSchools(familyUnitId: familyUnitId)` → store `allSchools`
2. `let schoolIds = schools.map(\.id)` (guard empty → `[]`)
3. `let coaches = try await dashboardService.fetchCoaches(schoolIds: schoolIds)`
4. `coachesNeedingFollowup = CoachFollowup.sorted(coaches.filter { CoachFollowup.needsFollowup($0, asOf: .now) }, asOf: .now)`

Runs concurrently with existing events/metrics/interactions fetches. Failure degrades gracefully (empty list), matching the existing per-fetch error handling.

### 2. Follow-up logic — pure functions (testable)

New file `Features/Dashboard/Models/CoachFollowup.swift`:

```swift
enum CoachFollowup {
  static let defaultThresholdDays = 14

  static func needsFollowup(_ coach: Coach, asOf now: Date, thresholdDays: Int = defaultThresholdDays) -> Bool {
    guard let last = coach.lastContactDateParsed else { return true }   // never contacted
    let cutoff = Calendar.current.date(byAdding: .day, value: -thresholdDays, to: now) ?? now
    return last < cutoff
  }

  /// Oldest-contact-first; never-contacted (nil) ranked first.
  static func sorted(_ coaches: [Coach], asOf now: Date) -> [Coach] {
    coaches.sorted { a, b in
      switch (a.lastContactDateParsed, b.lastContactDateParsed) {
      case (nil, nil): return false
      case (nil, _): return true
      case (_, nil): return false
      case let (x?, y?): return x < y
      }
    }
  }
}
```

**Threshold = 14 days** (web parity). **Known divergence:** iOS's existing `CoachAnalytics.needFollowUpCount` uses 30 days; the dashboard widget (14) and that analytics card (30) will report different counts. Accepted per product decision; documented here so it is not mistaken for a bug.

### 3. UI

New `Features/Dashboard/Components/CoachFollowupWidget.swift` + `CoachFollowupRow.swift`, following the card style of `UpcomingEventsWidget` (`.background(Color.Surface.card)`, `.clipShape(.rect(cornerRadius: 12))`, `.brandShadowSm()`).

Widget:
- Header "Coaches Needing Follow-up" (`.font(.headline)`, `.accessibilityAddTraits(.isHeader)`) + count badge.
- Empty state: "🎉 All caught up! / No coaches need immediate follow-up".
- Rows: first 5 by default; "Show N more" / "View all" expander (same pattern as `UpcomingEventsWidget`'s `isShowingAll`).

Row (`CoachFollowupRow`):
- `coach.fullName`
- school name via `EntityNameLookup.schoolName(for: coach.schoolId, in: schoolNameMap)`
- days-since string: `nil` → "Never contacted"; else "Today" / "1 day ago" / "N days ago" (a small pure formatter, unit-tested).
- Actions: **Email** (shown only if `coach.email != nil`), **Text** (only if `coach.phone != nil`), **View Profile**. Minimum 44×44pt hit targets, accessibility labels per project a11y standard.

### 4. Actions — reuse existing communication + detail

- **Email / Text** → present the existing `QuickCommunicationView` sheet (`.sheet(item:)`) seeded with the coach + resolved school name. This gives in-app compose + automatic interaction logging (`logSend`) — a superset of web behavior.
- **View Profile** → `.sheet` presenting `CoachDetailView(coachId:allCoaches:allSchools:)`, passing the loaded `coachesNeedingFollowup` (as `allCoaches`) and `allSchools`. Sheet chosen because no tab-switch infrastructure exists and it keeps the feature self-contained.
- **"View all N"** → sheet presenting the coaches list (reuse `CoachesListView` if it can be seeded, otherwise an expanded in-widget list). Detail decided in planning; not blocking.

### 5. Placement + visibility flag

- Add `coachesFollowup: Bool` to `WidgetVisibility`: property (default `true`), memberwise init param, `CodingKeys` case, `decodeIfPresent(... ) ?? true`, and the `.default` instance.
- Add a toggle row to `DashboardCustomizationView` mirroring `eventsSummary` (`:126`), and the corresponding line in `DashboardCustomizationViewModel`.
- Render in `DashboardChartsAndDataSection`, immediately after `UpcomingEventsWidget`, gated:
  ```swift
  if visibility.coachesFollowup && !coachesNeedingFollowup.isEmpty {
    CoachFollowupWidget(coaches: coachesNeedingFollowup, schools: allSchools)
  }
  ```
  Thread `coachesNeedingFollowup` + `allSchools` through `DashboardChartsAndDataSection`'s params (like `events`).

### 6. Testing

- `TheRecruitingCompassTests/.../CoachFollowupTests.swift` (pure fn):
  - `needsFollowup`: nil contact → true; exactly 14 days → boundary (define: `< cutoff`, so 14d-ago-exactly is NOT stale, 15d is); 13d → false; 15d → true.
  - `sorted`: never-contacted first, then oldest→newest.
  - days-since formatter: nil / today / 1 / N.
- ViewModel test: mocked `DashboardManaging` returning schools+coaches → `coachesNeedingFollowup` populated + correctly filtered/sorted; empty schools → empty list, no crash.
- Widget test: empty-state renders "All caught up"; N coaches renders N rows (cap 5) + expander.

Follow existing mock/`@MainActor` test conventions. Any new `@MainActor` class gets `nonisolated deinit {}` per project rule.

## Out of scope (restated)

- Upcoming Events empty-data investigation.
- `UpcomingEventsWidget` past-events sort bug.
- Other web-only widgets (Offers status, Upcoming Deadlines, School Map, Recruiting Calendar, Recent Documents, …).

## Open questions

- **"View all N"** target: sheet-wrap `CoachesListView` vs. in-widget expand. Resolve in planning.
- Whether to also reconcile the 14-vs-30-day divergence with `CoachAnalytics` later (not now).
