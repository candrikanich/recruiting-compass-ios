# iOS "Distance from Home" — School Detail Parity

**Date:** 2026-08-08
**Branch:** `feature/action-item-buttons` (current) — new branch recommended: `feature/distance-from-home`
**Status:** Design — awaiting spec review

## Problem

Web shows "Distance from Home: 372 miles" under the school map on the school detail
page when both the school and the player's home have coordinates. iOS does not display
it, even though the rendering code already exists in `SchoolMapView.swift:34-46`.

### Root cause

`SchoolDetailView.swift:80-86` computes `homeLocation` **only** from
`familyManager.familyUnit?.homeLatitude/homeLongitude` (the `family_units.home_latitude/
home_longitude` columns).

- No iOS code ever **writes** those columns (repo-wide grep: zero write sites).
- Those columns **do not exist** in the web schema at all (`family_units` has no
  `home_latitude`/`home_longitude`).

So `homeLocation` is always `nil` → `SchoolMapView` never renders the distance row.

The **correct, web-compatible** store is `user_preferences` (category `location`, JSON
fields `latitude`/`longitude`). This is:
- what the web app reads for its distance (`usePreferenceManager.getHomeLocation` →
  `user_preferences` category `location`), and
- what the iOS Home Location settings screen already **writes**
  (`HomeLocationViewModel.saveLocation()` → `PreferenceServiceImpl` →
  `user_preferences`, category `.location`), and
- what `SchoolsListViewModel` already **reads correctly** as a fallback
  (`SchoolsListViewModel.swift:199-219`).

`SchoolDetailViewModel` simply never adopted the pattern the list already uses.

## Reference implementation (already correct)

`SchoolsListViewModel` is the template. Its `homeLocation` (lines 34-47) prefers the
dead `FamilyUnit` coords, then falls back to `homeLocationFromPreferences`, which it
loads from `user_preferences` category `.location` in `loadSchools()` (lines 199-219).
Because the FamilyUnit branch is always nil, the fallback is what actually works.

## Design

### 1. School Detail — read home from `user_preferences`

`SchoolDetailViewModel`:
- Inject `preferenceService: any PreferenceManaging` (protocol DI, same type the list
  and Settings already use) via the initializer.
- Add `private(set) var homeCoordinate: CLLocationCoordinate2D?`.
- Add `func loadHomeLocation() async` that fetches
  `try await preferenceService.fetchPreferences(category: .location)` as `HomeLocation`,
  sets `homeCoordinate` from `latitude`/`longitude` (nil if either missing). Silent on
  error (match the list's rationale, `SchoolsListViewModel.swift:209-216`): a
  preferences fetch failure must not block the detail view.
- Call `loadHomeLocation()` alongside the existing school load / on appear.

`SchoolDetailView.swift:80-86`:
- Delete the `familyManager.familyUnit?.homeLatitude/homeLongitude` computed
  `homeLocation`.
- Pass `viewModel.homeCoordinate` to `SchoolMapView(homeLocation:)`.
- Re-fetch `homeCoordinate` when the Home Location sheet dismisses (state 3b below).

### 2. Distance formula + format parity (`DistanceCalculator.swift`)

Match web (`utils/distance.ts`) exactly:
- Haversine with `R = 3958.8` miles, `round()` to nearest whole mile.
  (Current iOS uses `CLLocation.distance / 1609.34` + `Int()` truncation — can differ
  by ~1 mile and never rounds up.)
- Add `static func formatMiles(_ miles: Int) -> String` returning
  `"<n,nnn> miles"` — thousands separator via `NumberFormatter` (web uses
  `toLocaleString()`), e.g. `"1,234 miles"`.
- Route `SchoolMapView` through `DistanceCalculator` (haversine + `formatMiles`); delete
  the inline `SchoolMapView.calculateDistance()` (lines 73-81).

`String(localized:)` for the label; the localized template becomes
`"Distance from Home: \(formatted)"` where `formatted` already includes " miles".
(Keep one localizable unit — do not split number and "miles" into separate keys.)

### 3. `SchoolMapView` guidance states

| # | Condition | UI |
|---|---|---|
| 1 | school coords + home coords | `Distance from Home: 372 miles` (existing row, new formatting) |
| 2 | school coords, **no** home coords | **Tappable CTA**: "Set your home location to see distance" → presents `HomeLocationView` sheet |
| 3 | **no** school coords | Existing empty state: "Location data not available" / "Use 'Lookup College Data' to fetch location" — **unchanged** |

State 2 detail:
- New view state in `SchoolMapView` shown when `school.academicInfo` has coords but
  `homeLocation == nil`.
- Button styled as a subtle CTA (secondary), left-aligned under the map, mappin icon,
  min 44pt hit target, `accessibilityLabel` "Set your home location to see distance to
  schools".
- Tapping presents `HomeLocationView(preferenceService:)` as a `.sheet`
  (self-contained — already parameterized only by `preferenceService`; no cross-tab
  navigation needed). `preferenceService` passed down from `SchoolDetailView`.
- On sheet `onDismiss`, call `viewModel.loadHomeLocation()` so a newly-set home
  immediately flips the view to state 1.

### 4. Schools list — remove dead store (cleanup)

`SchoolsListViewModel`:
- `homeLocation` getter (lines 35-47): drop the `familyManager.familyUnit?.homeLatitude/
  homeLongitude` branch; return `homeLocationFromPreferences` directly.
- `loadSchools()` (lines 199-219): drop the `familyManager.familyUnit?...` guard;
  always load from `user_preferences`.
- Remove the now-unused `familyManager` dependency **only if** nothing else in the VM
  uses it (verify — it may still be needed for `familyUnitId`). If still used, leave the
  property, just remove the home-coord reads.

### 5. Dead-column note

`FamilyUnit.homeLatitude/homeLongitude` (`FamilyUnit.swift:11-12,23-24`) become fully
unused after this change. Leave the model fields (harmless, decode-only) but this spec
documents them as dead — a future cleanup can drop them. Do **not** remove in this
change to avoid touching the Family feature's decode/tests unnecessarily.

## Files touched

- `Features/Schools/ViewModels/SchoolDetailViewModel.swift` — inject
  `preferenceService`, add `homeCoordinate` + `loadHomeLocation()`.
- `Features/Schools/Views/SchoolDetailView.swift` — repoint `homeLocation` →
  `viewModel.homeCoordinate`; pass `preferenceService`; sheet reload.
- `Features/Schools/Components/SchoolMapView.swift` — state 2 CTA; route distance
  through `DistanceCalculator`; delete inline `calculateDistance()`.
- `Core/Utilities/DistanceCalculator.swift` — web-parity haversine + `formatMiles`.
- `Features/Schools/ViewModels/SchoolsListViewModel.swift` — drop dead FamilyUnit
  branch.
- Callers constructing `SchoolDetailViewModel` — pass `preferenceService` (verify all
  construction sites, incl. previews + tests).

## Testing

- `DistanceCalculatorTests`: haversine matches web values (e.g. known city pair →
  same integer as web `Math.round`); `formatMiles` produces thousands separator;
  `formatMiles(0)`, large values.
- `SchoolDetailViewModelTests`: `loadHomeLocation()` sets `homeCoordinate` when prefs
  have lat/long; nil when missing lat OR long; nil (no throw) when
  `preferenceService.fetchPreferences` throws (mock). Use existing `MockPreferenceService`
  / `PreferenceManaging` mock pattern.
- `SchoolMapView` state selection: unit-assert the internal state (distance row vs CTA
  vs empty) via exposed computed properties (project a11y-unit pattern — expose non-
  private computed vars, construct the View, assert), for all 3 states.
- Regression: `SchoolsListViewModel` distance sort/filter still works reading from
  preferences only.

## Non-goals

- Writing `family_units.home_latitude/home_longitude` (dead columns; not in web schema).
- Changing state 3 (school-coords-missing) copy or the Lookup flow.
- Removing `FamilyUnit` model fields (documented dead; separate cleanup).
- iPad-specific layout.

## Open questions

None.
