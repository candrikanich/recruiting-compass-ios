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

## Status (2026-08-18)

- ✅ **profileLink** — absolute `https://myrecruitingcompass.com/p/<slug>`. iOS
  `feat/quick-comm-wizard`@69e4066c; web `feat/hometown-location-prefs`@d948bfe9.
- ✅ **Optional-var engine** — `renderClean` on both platforms (byte-identical, 8
  shared vectors). Optional-empty tokens/lines dropped; only `is_required_default`
  gates send. iOS@ee67b554; web@ecdedbfd.
- 🟡 **videoLink** — CODE ready both sides (iOS already derives; web now queries
  `video_links` → `derived.videoLink`, web@792f8c7b). **Registry flip pending** (see
  Coordinated steps).
- 🟡 **users.* drift** — root cause found (below); fix is a source-of-truth decision.
- ⬜ **authored → profile-backed** (`intendedMajor`/`academicHonors`/`classRank`).

## #3 drift — ROOT CAUSE

Trigger `sync_player_prefs_to_users()` (web migration
`20260816000000_coach_outreach_phase0_1.sql:158-198`):
- fires only on `user_preferences.category = 'player'`;
- syncs just 5 fields: `height_inches, weight_lbs, high_school, club_team, dominant_side`.

Writers:
- Web `PATCH /api/user/preferences/player-details` writes `category='player_details'`
  → **trigger never fires** → users.* goes stale on web edits.
- Web `PATCH /api/athlete/profile-field` writes `users.*` **directly** (inline edits),
  no reverse sync back to prefs.
- iOS writes `category='player'` → trigger fires (for its 5 fields only).
- `gpa/act_score/sat_score/graduation_year/jersey_number` are in NO sync path.

Net: `users.*` is a **broken mirror**; player prefs is the store athletes actually edit.
That's why templates (which read `column:users.*`) send stale values.

### Fix options (pick one — architectural, not auto-applied)
- **A. Tactical — repair the sync.** Make the trigger fire on the category web writes
  (align web to `'player'` OR broaden the trigger), add the 5 missing fields, and
  backfill drifted rows. Retire/redirect the direct `profile-field` writer or make it
  also update prefs. Keeps template mappings as-is.
- **B. Strategic — prefs as sole source of truth.** Repoint the mirrored template vars
  from `column:users.*` to `pref:player.*` (consistent with playerEmail/phone/ncaaId),
  add computed rewrites for `height`/`weight`/`testLabel`/`testScore` to read prefs.
  `dominantSide`/`jerseyNumber` have no prefs key (would need one or stay on users).
  Bigger, but removes the mirror from the template path entirely.

Recommendation: **B** long-term (matches the hometown/email fixes we just shipped);
**A** as a stopgap if a fast correctness patch is needed before B lands.

## #5 authored → profile-backed (proposal)

`intendedMajor`, `academicHonors`, `classRank` are stable athlete facts retyped every
message. To auto-fill: add them to player prefs (`pref:player.intended_major`, etc.),
add fields to the player-details editor (iOS + web), repoint the 3 registry rows from
`authored` → `column`/`pref:player.*`. Small DB + form work per platform; deferred
pending go-ahead.

## #3 drift — RESOLVED (2026-08-18)

Decision: **player-prefs jsonb is the source of truth for templates.** Ground truth —
there is NO `player_details` category; all player data lives in `user_preferences`
category `player`. The drift was `users.*` columns (written by a separate inline
`/api/athlete/profile-field` writer + partial trigger) diverging from the `player` jsonb
(written by the full profile editors + iOS).

Fix shipped both platforms: computed `height`/`weight`/`testLabel`/`testScore` read
`ctx.prefs`; registry repoints `gpaUnweighted`/`clubTeam`(→travel_team_name)/`highSchool`/
`gradYear` to `pref:player.*`. `dominantSide`/`jerseyNumber` stay on `users` (no prefs
key). iOS `7f1b927c`; web `d03fadf2`. Edge accounts with data only in `users.*` degrade
gracefully (optional-engine drops empty lines).

Follow-up (separate): the inline `profile-field` API still writes `users.*` only — retire
it or make it also write the `player` jsonb so the two never re-diverge.

## Feature build 2026-08-18 — status

- #1 phone `(xxx) xxx-xxxx`: iOS `762f0930` + web `f6d8b97c` ✅
- #2 Intended Major: iOS `0b717ad0` (Academics field) + web field/type/migration `d20352f5` ✅
  (web auto-fill now works too — #3 drift resolved, prefs is truth).
- #3 metrics CTA: iOS `396839b6` ✅. **Web: TODO** (CommunicationPanel nudge).
- #4 why-program/why-fit: iOS `1fb2a48c` (compose focused step + prefill/save + school
  detail) ✅. DB migration + registry ✅. **Web: TODO** (see below).

### Remaining WEB parity (needs runtime verification by a human)
1. #3 — metrics-empty CTA in `components/CommunicationPanel.vue` linking to the metrics editor.
2. #4 — add `why_program`/`fit_reason` to the web `School` type (`types/models.ts:62`);
   prefill `programNote`/`fitReason` in CommunicationPanel from the school + save back on send;
   optional focused "make it specific" step (iOS has one; web could keep the panel inputs).
3. #4 — editable "Why this program / Why it fits" fields on `pages/schools/[id]/index.vue`
   (reuse `SchoolNotesCard.vue`), patched via the school update endpoint.
   iOS is the reference implementation (`QuickCommunicationView` specificity step +
   `SchoolDetailView` fields + `SchoolsManaging.fetch/updateOutreachNotes`).

## Coordinated steps (deploy-ordered, NOT yet applied)

1. **videoLink registry flip** — after BOTH platforms deploy the videoLink derive
   (iOS already; web@792f8c7b), run:
   `update template_variables set source_type='computed', source_path=null where key='videoLink';`
   Flipping earlier makes videoLink briefly empty on whichever side hasn't deployed.
2. **#3 fix** — per decision A or B above.
3. **#5** — after the profile fields ship.
