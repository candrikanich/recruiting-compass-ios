# iOS handoff — canonical athlete positions (remove "Infielder", match web)

**Date:** 2026-08-10
**Direction:** web → iOS. Web is the source of truth (already shipped to prod).
**Companion web work:** PR #354 (`utils/positions/canonical.ts`) + live DB backfill.

---

## HANDOFF PROMPT (paste into the iOS session)

> Bring iOS athlete positions to parity with web (shipped in web PR #354). "Infielder"/"Outfielder" are not real positions and have been removed everywhere on web; onboarding and the family/edit pickers now offer ONE canonical, full-name, granular vocabulary per sport, and the shared DB has been backfilled so stored `primary_position` / `positions` are already canonical.
>
> Do this on iOS:
> 1. Replace `OnboardingConstants.sportPositions` and `FamilyConstants.Positions.all` with the canonical sport-scoped map below (make `FamilyConstants` sport-scoped too — parent picks sport, then position).
> 2. Add a sport-scoped `normalizePosition(sport:_ value:)` mirroring web (expand abbreviations, map coarse buckets `Infielder`/`Outfielder` → `Utility`, resolve `C`=Catcher vs Center and `P`=Pitcher vs Punter by sport, PRESERVE unknown values — never drop). Apply it when reading a stored `primary_position`/`positions` so any legacy value displays/selects cleanly.
> 3. Verify `PlayerDetails.completenessScore` is unchanged (it already scores `primaryPosition` presence at 0.10 — no change needed).
> 4. Confirm no picker still lists "Infielder"/"Outfielder"/"Guard"/"Lineman".
>
> Read the full spec at `planning/2026-08-10-ios-canonical-positions-parity.md`. Don't touch web files.

---

## Why

Web unified six conflicting position vocabularies into one canonical source. iOS is now the last place offering the coarse "Infielder"/"Outfielder" (and `FamilyConstants` offers even coarser "Guard"/"Lineman"). Parent (iOS) and player (web) must see the same options, and stored values must round-trip identically. The shared DB is already canonical (web backfilled it), so iOS mainly needs to (a) offer the canonical vocabulary and (b) normalize any legacy value defensively on read.

## Files to change

| File | Current | Change |
|---|---|---|
| `Features/Onboarding/Utilities/OnboardingConstants.swift` | `sportPositions` sport-scoped, coarse (Infielder/Outfielder) | Replace with canonical map below |
| `Features/Family/Utilities/FamilyConstants.swift` | `Positions.all` FLAT coarse list (Guard, Lineman, …) | Make sport-scoped; use canonical map |
| `Features/Onboarding/ViewModels/OnboardingViewModel.swift` | reads `OnboardingConstants.sportPositions` | verify still compiles; picker shows canonical |
| `Features/Family/ViewModels/ParentOnboardingWizardViewModel.swift` + family pickers (`FamilyManagement*`, `ParentFamilyCard`, `FamilyMemberCard`) | read `FamilyConstants.Positions.all` | switch to sport-scoped canonical lookup |
| `Features/Preferences/Models/PlayerDetails.swift` | `completenessScore` scores `primaryPosition` presence (0.10) | NO change — parity already correct |

New: a canonical positions helper (Swift equivalent of web `utils/positions/canonical.ts`) with `positions(for sport:)` and `normalize(sport:_ value:)`.

## Canonical map (mirror web `SPORT_POSITIONS` exactly)

```
Baseball / Softball: Pitcher, Catcher, First Base, Second Base, Third Base,
  Shortstop, Left Field, Center Field, Right Field, Designated Hitter, Utility
Basketball: Point Guard, Shooting Guard, Small Forward, Power Forward, Center
Football: Quarterback, Running Back, Wide Receiver, Tight End, Offensive Line,
  Defensive Line, Linebacker, Defensive Back, Kicker, Punter
Soccer: Goalkeeper, Defender, Midfielder, Forward
Volleyball: Outside Hitter, Middle Blocker, Setter, Libero, Opposite Hitter, Defensive Specialist
Track & Field: Sprinter, Distance Runner, Jumper, Thrower, Hurdler
Swimming: Freestyle, Backstroke, Breaststroke, Butterfly, Individual Medley, Diver
Cross Country: Runner
Tennis: Singles, Doubles
Golf: Golfer
Lacrosse: Attackman, Midfielder, Defenseman, Goalie
Field Hockey: Forward, Midfielder, Defender, Goalkeeper
Ice Hockey: Forward, Defenseman, Goalie
Wrestling: Wrestler
Rowing: Rower
Water Polo: Field Player, Goalkeeper
```

## Normalization rules (mirror web)

- **Sport-scoped** — resolve by sport, never a flat map. Collisions: `C` = Catcher (baseball) vs Center (basketball); `P` = Pitcher (baseball) vs Punter (football).
- Expand abbreviations: `P→Pitcher, C→Catcher, 1B→First Base, 2B→Second Base, 3B→Third Base, SS→Shortstop, LF→Left Field, CF→Center Field, RF→Right Field, DH→Designated Hitter, UTIL→Utility`; `PG→Point Guard, SG→Shooting Guard, SF→Small Forward, PF→Power Forward`; `QB→Quarterback, RB→Running Back, WR→Wide Receiver, TE→Tight End, OL→Offensive Line, DL→Defensive Line, LB→Linebacker, DB→Defensive Back, K→Kicker`; `GK→Goalkeeper, DEF→Defender, MID→Midfielder, FWD→Forward`.
- Coarse buckets → `Utility`: `Infielder, Outfielder, Infield, Outfield, IF, OF`.
- Already-canonical values pass through (case-insensitive). **Unknown values are PRESERVED, not dropped.**

## Migration / data

- No iOS-side DB migration needed — web already backfilled the shared project (`primary_position` + `positions[]` are canonical full names now).
- One real-user note: `owen@andrikanich.com`'s `primary_position` was `Utility` (migrated from his old "Infielder"; his `positions[]` = Second/Third Base, Shortstop, Pitcher). If iOS shows a parent an empty/odd primary, that's why — they can pick a specific spot in the canonical picker.

## Verify

- No picker lists "Infielder"/"Outfielder"/"Guard"/"Lineman"/"Center" (basketball Center stays, but no generic "Center" in a flat list).
- A baseball athlete with stored `Utility` shows "Utility" selected; `Shortstop` shows "Shortstop".
- Completeness for a complete athlete = 85 (unchanged), matching web.
- `swift build` / tests green.

## Out of scope (web Phase 2, separate)

- Web's dead `Screen2BasicInfo.vue` + object lookup, and the DB `positions` table vs `primary_position` string reconciliation — web-side, not iOS.
