# Phase 3 Spike — Per-Sport Athlete Attributes + Recruiting Services

**Date:** 2026-08-22 · research only, no code written · source: `2026-08-22-baseball-deprecation-remediation-plan.md` Phase 3

## Decisive architectural finding
`user_preferences` is `(user_id, category, data JSONB)`, unique `(user_id, category)`; player fields live at `category='player'` as **flat keys inside the `data` blob** (`server/migrations/016_*.sql:11-20`, `server/utils/hydrateAthleteProfile.ts:67,102`). `bats`/`throws`/`perfect_game_id` are **not typed columns** — they're flat JSONB keys. **→ Adding any new attribute/service key is ZERO migration.** Registry (code) supplies per-sport structure; DB stays a schemaless flat bag. Validation lives in Zod (web) + picker option set (iOS), same as `bats`/`throws` today.

## 17 canonical sports (byte-identical iOS `CanonicalPositions.bySport` ↔ web `SPORT_POSITIONS`)
Baseball, Softball, Basketball, Football, Soccer, Volleyball, Track & Field, Swimming, Cross Country, Tennis, Golf, Lacrosse, Field Hockey, Ice Hockey, Wrestling, Rowing, Water Polo.

## Spike 3a — Athlete Attributes registry
New: web `utils/attributes/canonical.ts`, iOS `Core/Utilities/AthleteAttributes.swift`. Shape mirrors metrics/positions: `ATTRIBUTES_BY_SPORT: Record<string, AttributeDef[]>` / `static let bySport: [String:[AttributeDef]]`. `AttributeDef { key, label, options[], optionLabels{} }`. Helper `attributes(for:)` mirrors `CanonicalPositions.positions(for:)`.

| Sport | key | Label | Options (stored→display) |
|---|---|---|---|
| Baseball, Softball | `bats` | Bats | L→Left, R→Right, S→Switch **(existing, unchanged)** |
| Baseball, Softball | `throws` | Throws | L→Left, R→Right **(existing, unchanged)** |
| Basketball | `shooting_hand` | Shooting Hand | L/R |
| Soccer | `dominant_foot` | Dominant Foot | L/R/Both |
| Volleyball | `hitting_hand` | Hitting Arm | L/R |
| Tennis | `racket_hand` | Plays | L/R |
| Tennis | `backhand_style` | Backhand | one/two |
| Golf | `golf_handedness` | Plays | L/R |
| Lacrosse | `dominant_hand` | Dominant Hand | L/R |
| Ice Hockey | `shoots` | Shoots | L/R |
| Ice Hockey | `catches` | Catches (goalies) | L/R — **verify: gate to goalie?** |
| Water Polo | `wp_dominant_hand` | Dominant Hand | L/R |
| Rowing | `rowing_side` | Rigging Side | port/starboard/both/cox |
| Rowing | `rowing_discipline` | Discipline | sweep/scull/both |
| Football | `throwing_hand` | Throwing Hand | L/R — **verify: QB-only?** |
| Football | `kicking_foot` | Kicking Foot | L/R — **verify: K/P-only?** |

No attribute (correct, don't invent): Track & Field, Cross Country, Swimming, Field Hockey (sticks right-only by rule), Wrestling (flag for product).
**Value convention:** reuse `L`/`R`/`S` single-char tokens everywhere (matches existing `bats`/`throws`, trivial Zod/Codable). Multi-state → short lowercase tokens. `optionLabels` live in registry only, never DB.

## Spike 3b — Recruiting Services registry
Keep PG/PBR gated to baseball/softball. New: web `utils/services/canonical.ts`, iOS `Core/Utilities/RecruitingServices.swift`. `ServiceDef { key, label, valueKind: id|url|username, urlTemplate?, signupUrl, placeholder }`, `SERVICES_BY_SPORT`. Renders by iterating the registry instead of the hardcoded `v-if="isBaseballOrSoftball"` block (`PlayerDetailsAthleticsTab.vue:257-305`, public card `PublicProfileCard.vue:310-320`).

**Confirmed:** Perfect Game `https://www.perfectgame.org/Players/Playerprofile.aspx?ID={value}` (baseball/softball).
**v1 safe subset:** NCSA (all sports) + Hudl (broad, store full `url`) + existing PG/PBR. Add sport-specific (Athletic.net, SwimCloud, UTR, Elite Prospects, TopDrawerSoccer, SportsRecruits, MileSplit, Junior Golf Scoreboard, TrackWrestling, Concept2, On3/247…) as URL patterns are **verified** — until then render `signupUrl`-only (label + marketing link, value as plain text). **Never ship a guessed profile-URL template.**

## Storage recommendation (both spikes): flat JSONB keys, ZERO migration
Do NOT add typed columns. Do NOT nest under an `athlete_attributes`/`services` sub-object (breaks flat token resolution `{{bats}}` + forces both platforms to special-case a container). New keys join `data` flat, exactly like `perfect_game_id`. Per key: web adds `z.enum([...]).nullable().optional()` to `playerDetailsSchema`; iOS adds optional `var` + CodingKey.

## Parity — must be byte-identical both platforms
1. All attribute/service **key strings** (mismatch = one platform writes a key the other can't read from shared blob).
2. **Option value tokens** (L/R/S, Both, one/two, port/starboard…); only display labels may differ.
3. **Sport→attribute/service membership** maps.
4. **`urlTemplate` strings** (public card builds links from these).
5. Sport keys already match — new registries MUST use same exact keys ("Track & Field", "Ice Hockey").
6. Any new attribute used as a **template token** must be added to both resolvers identically.

## Phase 3 build decisions — LOCKED (Chris, 2026-08-22)
1. **Football** — position-gate: `throwing_hand` shows only for QB, `kicking_foot` only for K/P. → `AttributeDef` gains optional `positions?: string[]`; when set, attribute renders only if athlete's position ∈ list. Same field added to Swift `AttributeDef`.
2. **Ice hockey** — `shoots` = all hockey athletes; `catches` position-gated to goalie(s) (same `positions` mechanism).
3. **Wrestling + Field Hockey** — no laterality attributes (confirmed).
4. **Token convention** — reuse `L`/`R`/`S` single-char tokens across all sports (locked storage contract).
5. **Services v1** — NCSA (all sports) + Hudl (broad, `valueKind:"url"`) + existing gated PG/PBR ONLY. Sport-specific services added incrementally as real profile-URL patterns are verified. No guessed URL templates.
6. Public-card layout scaling — resolve at build time (design detail).

New registry contract note: `AttributeDef` = `{ key, label, options[], optionLabels{}, positions?[] }` on BOTH platforms; `positions` empty/absent = sport-wide.

## Original open questions (now resolved above)
1. Football `throwing_hand`/`kicking_foot` — always / position-gated / omit v1?
2. Ice hockey `catches` — goalie-only or all hockey athletes?
3. Wrestling + Field Hockey — accept no laterality attribute, or add stance/other?
4. Confirm `L`/`R`/`S` token reuse across all sports (locks storage contract).
5. Services v1 — full long-tail table now, or NCSA+Hudl+PG/PBR first, rest as verified?
6. Public-card layout scales to ~2 attributes + 1–3 services per sport? (currently fixed baseball-shaped block)
