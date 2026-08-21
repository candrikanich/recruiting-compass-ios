# Spec: Multi-sport performance metrics

**Date:** 2026-08-21
**Status:** DRAFT — architecture proposed, per-sport metric content needs Chris's review
**Platforms:** iOS + web (byte-identical registry, like positions)
**Repos:** recruiting-compass-ios, recruiting-compass-web

---

## Problem

The profile layer is multi-sport (17 sports in the `sports` table; sport-scoped positions
already exist). The **metric-type system is baseball/softball-only**: a fixed 8-key enum
(`velocity, exit_velo, sixty_time, pop_time, batting_avg, era, strikeouts, other`) shown to
every athlete regardless of `primary_sport`. A basketball/soccer/etc. athlete's only path is
the generic `other` type (value + picked unit, **no name**), which renders in coach emails as
literally "other: 22". No sport↔metric linkage exists in UI, DB, registry, or resolver.

## Goal

Every offered sport gets a set of sport-appropriate, correctly-formatted metric types. The
metric logger offers the athlete's sport's metrics (+ `other` fallback). Coach-outreach
templates render them with proper labels and formatting.

---

## Architecture (mirror the positions pattern)

The app already solves exactly this shape for **positions**: a canonical sport→list map shared
byte-identical across platforms (`utils/positions/canonical.ts` / `CanonicalPositions.swift`)
plus a `sports` DB table. Do the same for metrics.

### 1. `MetricDef` — one metric type's definition

```
key            String   // globally-unique, stored verbatim in performance_metrics.metric_type
label          String   // display name ("Batting Average", "Points Per Game")
unit           String   // "mph", "sec", "%", "", "count", "in", "m", ...
format         Format   // how the value renders (below)
lowerIsBetter  Bool     // trend direction (times, ERA, golf score)
```

### 2. `Format` kind — replaces today's per-type precision guesswork

| Format | Rule | Example |
|---|---|---|
| `.decimal(digits, dropLeadingZero)` | fixed decimals; optionally strip leading 0 | `.410` (3,true), `3.45` (2,false), `82.3` (1,false) |
| `.integer` | whole number | `12` |
| `.percent(digits)` | fixed decimals + `%` unit rendering | `45.0%`, `.350` variants decided per sport |
| `.duration` | MM:SS.hh from a seconds value | `1:52.34`, `9:41.0` |

This subsumes the current `MetricType.format` / `formatMetricValue` (batting_avg =
`.decimal(3,true)`, era = `.decimal(2,false)`, velocity = `.decimal(1,false)`, times =
`.decimal(2,false)`, strikeouts = `.integer`). **`.duration` is new** and required for
track/swim/XC/rowing.

### 3. Registries (byte-identical iOS + web)

```
metricDefs: [key: MetricDef]        // every metric across all sports, keyed by unique key
sportMetrics: [sport: [key]]        // ordered metric keys offered per sport
```

Defs are shared across sports (softball reuses the baseball keys). `sportMetrics[sport]` drives
the logger's type list; append the universal `other` at the end of every sport.

### 4. What changes

- **iOS:** `MetricType` today is a closed enum used for `format`, `defaultUnit`, `isLowerBetter`,
  `unitVocabulary`, `unitIsFixed`. Migrate to registry-backed: a metric type is a `String` key +
  `metricDefs[key]` lookup. Keep the 8 existing keys as registry entries (zero data migration —
  `metric_type` is already free `text`). `MetricType.format` → `MetricDef.format`. `formattedValue`,
  `MetricFormState`, `TrendCard`, `LatestMetricCard`, `TemplateComputed` route through the def.
- **web:** `formatMetricValue` consults `metricDefs[key].format`. `LogMetricModal` renders
  `sportMetrics[primary_sport]` instead of the static `metricTypes` const; unit locked to
  `def.unit` (except `other`). `templateResolver.humanizeMetricLabel` uses `def.label` when known.
- **DB:** none required (`metric_type` stays unconstrained `text`). Optionally seed a
  `metric_types` reference table later for parity with `sports`, but not needed to ship.
- **Logger UI (both):** filter type list by `primary_sport`; always include `other`. A player
  with no sport set → show a sensible default (all, or baseball) — decide in review.
- **`other`:** add a **custom name** field so non-registry metrics stop rendering as "other".
  (Small, valuable even independent of this feature.)

### 5. Back-compat

Existing rows keep their `metric_type` strings; all 8 baseball keys remain valid registry
entries. No migration, no data loss. Unknown/legacy keys fall back to `.decimal`-plain + the
humanized key as label (today's behavior).

---

## Draft per-sport metric content — REVIEW / EDIT ME

Recruiting-relevant metrics per sport. Format shorthand: `dec(d[,drop0])`, `int`, `pct(d)`,
`dur`. `↓` = lower is better. **Chris: correct the metrics, units, and precision per your
recruiting domain knowledge — this is a first draft, not authoritative.**

### Baseball / Softball (existing + additions)
velocity `mph` dec(1) · exit_velo `mph` dec(1) · sixty_time `sec` dec(2)↓ · pop_time `sec` dec(2)↓ ·
batting_avg `` dec(3,drop0) · on_base_pct `` dec(3,drop0) · slugging_pct `` dec(3,drop0) ·
era `` dec(2)↓ · whip `` dec(2)↓ · strikeouts `count` int · fielding_pct `` dec(3,drop0)

### Basketball
points_per_game `` dec(1) · rebounds_per_game `` dec(1) · assists_per_game `` dec(1) ·
steals_per_game `` dec(1) · blocks_per_game `` dec(1) · field_goal_pct `%` pct(1) ·
three_point_pct `%` pct(1) · free_throw_pct `%` pct(1) · vertical_jump `in` dec(1)

### Football
forty_time `sec` dec(2)↓ · bench_press `reps` int · vertical_jump `in` dec(1) ·
broad_jump `in` int · shuttle `sec` dec(2)↓ · three_cone `sec` dec(2)↓ · squat `lbs` int ·
passing_yards `yds` int · rushing_yards `yds` int · receiving_yards `yds` int · tackles `count` int

### Soccer
goals `count` int · assists `count` int · saves `count` int · clean_sheets `count` int ·
minutes_played `count` int

### Volleyball
kills `count` int · blocks `count` int · digs `count` int · aces `count` int ·
assists `count` int · hitting_pct `` dec(3,drop0)

### Track & Field
sprint_time `sec` dec(2)↓ · distance_time `` dur↓ · relay_split `sec` dec(2)↓ ·
long_jump `m` dec(2) · high_jump `m` dec(2) · shot_put `m` dec(2) · discus `m` dec(2)

### Cross Country
race_time `` dur↓ · pace_per_mile `` dur↓

### Swimming
free_50 `sec` dec(2)↓ · free_100 `` dur↓ · event_time `` dur↓ (generic)

### Golf
scoring_average `strokes` dec(1)↓ · handicap `` dec(1)↓

### Tennis
utr_rating `` dec(2) · singles_record `` (text?) · ranking `` int↓

### Wrestling
record `` (text W-L?) · pins `count` int · takedowns `count` int · weight_class `lbs` int

### Lacrosse
goals `count` int · assists `count` int · ground_balls `count` int · saves `count` int

### Ice Hockey
goals `count` int · assists `count` int · points `count` int · save_pct `` dec(3,drop0) ·
goals_against_avg `` dec(2)↓

### Field Hockey
goals `count` int · assists `count` int · saves `count` int

### Rowing
erg_2k `` dur↓ · erg_split `` dur↓

### Water Polo
goals `count` int · assists `count` int · saves `count` int · steals `count` int

**Open content questions for review:**
- Percent convention: `45.0%` (pct) vs baseball-style `.450` (dec(3,drop0))? Currently proposed
  pct(1) for shooting %, dec(3,drop0) for hitting_pct/fielding — inconsistent on purpose or unify?
- Text-valued "metrics" (wrestling record, tennis singles record) don't fit a numeric value +
  unit. Exclude, or add a `.text` format kind (no aggregation/trend)?
- Which metric is a sport's default `is_primary` / `carryingTool` candidate?
- Per-sport ordering (most-recruiting-relevant first).

---

## Phasing

1. **Registry + formatter** — `MetricDef`/`Format` + `metricDefs`/`sportMetrics` on both platforms;
   extend `MetricType.format`/`formatMetricValue` (incl `.duration`, `.percent`). Baseball keys
   moved into the registry unchanged. TDD the formatter (esp. duration + percent). Both build/tsc green.
2. **Logger UI** — filter type list by `primary_sport` (+ `other`); add `other` custom-name field.
3. **Resolver labels** — `humanizeMetricLabel` → `def.label`; verify `{{metrics}}`/`{{carryingTool}}`.
4. **Content** — land all 17 sports' reviewed metric sets.

Each phase ships independently; existing baseball behavior is preserved throughout.

## Out of scope (for now)
- DB `metric_types` reference table (not needed; `metric_type` stays text).
- Historical re-typing of existing `other` rows.
- Sport-specific analytics/trends beyond formatting + labeling.
