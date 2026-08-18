# Template Variable Audit — 2026-08-18

Audit of all 79 `template_variables` registry rows: does each resolve for a real
athlete, and are there mapping/format bugs? Reference athlete: Owen Andrikanich
(`3d97c4dc-…`). Shared registry drives both iOS (`TemplateResolver`) and web
(`utils/templateResolver.ts`).

Legend: ✅ resolves · 🐞 bug · ✍️ authored (typed per-message, fine by design) ·
⚠️ resolves but data often empty / drift risk.

## 🐞 Bugs to fix

| key | source | problem | fix |
|---|---|---|---|
| `videoLink` | `column` → `pref:player.video_links` | Canonical film is the `video_links` **table**, not a player-prefs key. That prefs key is empty, so the token never fills; the table-derived `videoLink` (iOS `buildDerived:52`, web equivalent) is bypassed because `source_type=column` routes to prefs. | Change `source_type` to `computed` (uses derived table value) **or** repoint to the real source. Both platforms already derive it — just let the derived value win. |
| `profileLink` | `computed` → `/{slug}` | Relative path (`/hrz5o3`), not clickable in email/SMS. | Prepend public base URL → `https://<domain>/{slug}` in `buildDerived` (iOS) + `useTemplateResolver` (web). Needs prod public domain. |

## ⚠️ Data-integrity / drift

- **`users.*` mirror drifts from player prefs.** `users.club_team`="Release 17u
  Garcia" & `users.act_score`=32, but player-prefs `travel_team_name`="Release
  16u Garcia" & `act_score`=26. Templates read the `users.*` mirror
  (`clubTeam`, `testScore`), so a stale mirror = stale email. Investigate the
  sync (trigger? write path?) — which is source of truth, and why they diverged.
- Affected mirrored vars: `gpaUnweighted`(users.gpa), `clubTeam`(users.club_team),
  `dominantSide`, `highSchool`, `height`/`weight` (users.height_inches/weight_lbs),
  `testLabel`/`testScore` (users.act/sat_score), `gradYear`.

## ✅ Resolve correctly (spot-checked vs Owen)

- **player:** `playerName`(users.full_name), `playerFirstName`, `sport`,
  `position`/`positionSecondary`, `height`, `weight`, `gradYear`, `highSchool`,
  `hometownCity`/`hometownState` (fixed → `pref:location.*`), `gpaUnweighted`,
  `dominantSide`, `clubTeam`.
- **contacts:** `playerEmail`(pref:player.email, now populated), `playerPhone`,
  `clubCoachName`(pref:player.travel_team_coach), `ncaaId`.
- **program (from selected school/coach):** `coachFirstName`/`coachLastName`/
  `coachTitle`/`coachSalutation`, `schoolName`/`schoolShortName`/`schoolCity`/
  `schoolState`/`division`/`conference`/`schoolTwitter`.
- **metrics/academics:** `metrics`, `carryingTool`, `metricsAsOf` (need ≥1
  performance_metrics row; `carryingTool` needs one `is_primary`), `testLabel`/
  `testScore`, `transcriptLink` (needs uploaded transcript doc).
- **event (needs a linked event):** `eventName`/`eventLocation`/`eventDates`/
  `eventSchedule`/`nextEventName`/`nextEventDates`/`rosterLink`/`visitDate`.
- **system:** `todayDate`, `seasonLabel`, `daysSinceContact`, `contactWindowDate`.
- **hsCoachName** — computed from grade-level coach prefs (falls back across grades).

## ✍️ Authored (typed per message — by design; flagged for review)

- **Coach contact:** `hsCoachPhone`, `clubCoachPhone`, `hsCoachEmail`,
  `clubCoachEmail` — kept authored for privacy (removed from default bodies
  2026-08-18). OK.
- **Candidates to become profile-backed** (currently retyped every message):
  `intendedMajor`, `academicHonors`, `classRank` — stable athlete facts; could
  live in profile so they auto-fill.
- **Genuinely per-message (correct as authored):** `programNote`*, `fitReason`,
  `updateHook`*, `updateHookShort`, `specificMoment`*, `injuryNote`,
  `returnTimeline`, `offerDetails`, `performanceSummary`, `roleNote`,
  `roleChange`, `seasonStatLine`, `awards`, `teamAccomplishment`,
  `specificTakeaway`, `questionBack`, `answerTheirQuestion`, `filmDescription`,
  `decisionTimeframe`, `referrerName`, `teamAtEvent`, `programMascot`.
  (* = the three `is_required_default=true` vars.)

## Cross-cutting features (separate from per-var fixes)

1. **Optional-var / drop-empty-line engine** (both repos, shared tests): mark
   vars optional (`is_required_default` — already in DB, currently unread on both
   platforms), then empty-optional → omit its line / token and **don't** block
   send; empty-*required* → still block. Unifies "drop the `Film:` line when no
   video" with the parked no-block-on-optional ask.
2. **Only 3 vars are `is_required_default=true`** today (`programNote`,
   `specificMoment`, `updateHook`); everything else would become non-blocking
   once the engine reads the flag.

## Suggested order

1. `profileLink` full URL (needs prod domain) + `videoLink` source fix — small, high value.
2. Investigate the `users.*`-mirror drift (correctness of what actually sends).
3. Optional-var engine (design → plan → build, both repos).
4. Decide which authored vars graduate to profile-backed.
