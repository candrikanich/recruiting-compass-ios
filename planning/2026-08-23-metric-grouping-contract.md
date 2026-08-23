# Metric Grouping Contract (narrow — picker only, 6 dense sports)

Approved 2026-08-23: build narrow (log-metric picker section headers, 6 sports); dashboard grouping deferred.

## Design (byte-identical both platforms)
Do NOT add `category` to `MetricDef` — shared keys (`assists` = "Setting" in Volleyball vs "Attacking"
in Soccer/Ice Hockey) can't carry one global category. Instead add a PARALLEL per-sport group map,
mirroring the existing `SPORT_METRICS` ordering pattern (the proven parity mechanism).

- web `utils/metrics/canonical.ts`: `export interface MetricGroup { category: string; keys: readonly string[] }`
  + `export const SPORT_METRIC_GROUPS: Record<string, readonly MetricGroup[]>`. Category = plain display string.
- iOS `Core/Utilities/MetricRegistry.swift`: `struct MetricGroup: Sendable { let category: String; let keys: [String] }`
  + `static let sportMetricGroups: [String: [MetricGroup]]`. Category via `String(localized:)`.

Only these 6 sports get an entry. Every other sport has NO entry → renders flat exactly as today
(zero change, zero risk). A recorded key not in any group → trailing "Other" group / flat fallback.
Array order = section order; keys within a group in display order.

## Per-sport groups (exact)

| Sport | Category | Keys (in order) |
|---|---|---|
| Baseball | Hitting | exit_velo, batting_avg, on_base_pct, slugging_pct |
| Baseball | Pitching | velocity, era, whip, strikeouts |
| Baseball | Fielding | pop_time, fielding_pct |
| Baseball | Speed | sixty_time |
| Softball | *(same 4 groups as Baseball, same keys)* | |
| Basketball | Scoring | points_per_game, field_goal_pct, three_point_pct, free_throw_pct |
| Basketball | Playmaking | assists_per_game |
| Basketball | Defense | rebounds_per_game, steals_per_game, blocks_per_game |
| Basketball | Athleticism | vertical_jump |
| Football | Combine | forty_time, vertical_jump, broad_jump, shuttle, three_cone |
| Football | Strength | bench_press, squat |
| Football | Offense | passing_yards, rushing_yards, receiving_yards |
| Football | Defense | tackles |
| Track & Field | Running | sprint_time, distance_time, relay_split |
| Track & Field | Jumps | long_jump, high_jump |
| Track & Field | Throws | shot_put, discus |
| Volleyball | Attacking | kills, hitting_pct, aces |
| Volleyball | Setting | assists |
| Volleyball | Defense | blocks, digs |

The other 11 sports (Soccer, Lacrosse, Water Polo, Field Hockey, Ice Hockey, Wrestling, Swimming,
Cross Country, Golf, Tennis, Rowing): NO entry → flat. (Ice Hockey was marginal; skip for now.)

## UI wiring (log picker only)
- iOS `Features/Performance/Components/MetricFormView.swift` (the `Picker`, ~line 25): when
  `sportMetricGroups[sport]` exists, wrap `ForEach` in `Section(header: Text(group.category))` per group;
  else the current flat `ForEach` over `types(forSport:)`. Keys not in any group append under a final
  "Other" section (or stay flat). SwiftUI Picker supports sectioned content natively.
- web `components/Performance/LogMetricModal.vue` (the `<select>`, ~line 273): when groups exist, render
  `<optgroup :label="group.category">` per group; else the current flat `<option v-for>`.

Dashboard summary grouping = DEFERRED (weaker value; only shows already-recorded metrics). Not this pass.
Verify: iOS xcodebuild exit 0; web type-check 0 + lint 0. Add a registry test: SPORT_METRIC_GROUPS
covers exactly those 6 sports; every grouped key exists in that sport's metric set; ungrouped sports
return no groups.
