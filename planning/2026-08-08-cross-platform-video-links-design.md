# Cross-Platform Video Links — Design

**Date:** 2026-08-08
**Status:** Approved design → phased implementation
**Repos:** shared Supabase DB · `recruiting-compass-web` · `recruiting-compass-ios`

---

## 1. Problem

Video-related action items ("Add Video", "Update Video") can never be completed. The
whole video story is broken and split across three parallel, disconnected concepts:

| Concept | Storage | Reality |
|---|---|---|
| **`video_links[]`** | `user_preferences.data.video_links` (JSONB, category `player`) | The **only** store athletes actually populate. Shape `{platform, url, title}`, max 5, platforms `hudl\|youtube\|vimeo`. Edited in the web player-details Athletics settings tab (player-role only). Surfaced in recruiting-packet export + public-profile `film`. **No health field.** |
| **highlight_video documents** | `documents` rows `type='highlight_video'` | Uploaded video **files** in Storage. Has unused `health_status`/`last_health_check` columns + partial index. Nothing writes health; no rule reads it. iOS uploads these via `DocumentUploadSheet`. |
| **phantom `videos` table** | *does not exist* | Both suggestion rules query it via `(supabase as any).from("videos")` → always `[]`. Rules never fire. CTAs point at a non-existent `/videos` route (404). |

### Current wiring (broken)
- **Web rules:** `server/utils/rules/missingVideo.ts` (grade ≥10 && `videos.length===0` → `add_video`) and
  `videoLinkHealth.ts` (`health_status==='broken'` → `update_video`) both read the phantom table
  (`evaluate.post.ts:80-84`). Never produce suggestions.
- **Web CTAs:** `SuggestionCard.vue:155,161` → `navigateTo("/videos")` — dead link.
- **Web comms:** `templateVariables.ts` has **no** video/film variable. Video reaches coaches only
  indirectly via packet export + public profile.
- **iOS:** No Videos feature. "Video" = a `documents` highlight_video file. No `video_links` concept.
  Action-item CTAs have **zero navigation wiring** — no `actionType`→destination map exists
  anywhere; `add_video`/`add_school`/`log_interaction` appear only in `#Preview` mock data.

---

## 2. Decisions (locked)

1. **Canonical video = URL links** (`video_links`), not uploaded files. Uploaded highlight_video
   documents stay a separate "game-film files" concept, untouched.
2. **Promote `video_links` to a real table** (out of `user_preferences` JSONB) so rules query it
   directly, a background job can health-check per row, and RLS/indexing are clean.
3. **Coach comms = both** — add template variables **and** keep packet/profile reading the new table.
4. **iOS editor = player-details settings**, mirroring web IA. Player-role only; parents view-only.
5. **iOS CTA router = full** — map every known `action_type` with a real iOS target, not just video.
6. **Packaging:** one master design doc (this) → three phased implementation plans (A/B/C).
7. **Execution:** design + implement all three phases end-to-end (DB + web + iOS) from this workstream.

---

## 3. Shared contract

These strings/shapes are the contract every phase depends on — do not drift.

### `video_links` table
```
video_links
  id                uuid pk default gen_random_uuid()
  user_id           uuid not null  -> auth user of the PLAYER (owner)
  family_unit_id    uuid           -> parent read access (nullable, set on create)
  platform          text not null  CHECK in ('hudl','youtube','vimeo')
  url               text not null
  title             text
  position          int  not null default 0   -- display order 0..4
  health_status     text not null default 'unknown'  CHECK in ('healthy','broken','unknown')
  last_health_check timestamptz
  created_at        timestamptz not null default now()
  updated_at        timestamptz not null default now()
```
- **Max 5 per user:** enforced app-side on both platforms + a partial unique guard is impractical
  for a count cap, so use a `BEFORE INSERT` trigger (count check) OR trust app-side + document it.
  Decision: **trigger-enforced count cap** so the DB is the source of truth.
- **Indexes:** `(user_id)`, `(family_unit_id)`, partial `(health_status) WHERE health_status <> 'healthy'`
  (mirrors documents' health index for the cron).
- **RLS** (mirror `documents`/`offers`):
  - SELECT: `user_id = auth.uid()` OR `family_unit_id` in caller's family units.
  - INSERT/UPDATE/DELETE: `user_id = auth.uid()` AND caller role is player (parents blocked).
  - Health cron updates run under service role (bypass RLS).

### `action_type` → destination contract
| `action_type` | Web target | iOS target |
|---|---|---|
| `add_video` | player-details Athletics settings tab | Video-links editor (player-details settings) |
| `update_video` | same, deep-link to broken link if feasible | same |
| `add_school` | `/schools/new` | `AddSchoolView` (`SchoolDestination.add`) |
| `log_interaction` | `/interactions/add` | `AddInteractionView` (prefill related school) |
| *(unknown)* | Learn More only, no CTA | no CTA button, Complete/Dismiss only |

### Comms template variables
- `{{filmLinks}}` — all healthy links, rendered as `Title (PLATFORM): url` list.
- `{{primaryFilmLink}}` — first healthy link by `position`; empty string if none.

---

## 4. Phase A — Data layer (must ship first)

**Repo:** shared Supabase migrations (authored in `recruiting-compass-web/supabase/migrations`,
the canonical migration home).

1. `CREATE TABLE video_links` per §3 + indexes + count-cap trigger.
2. RLS policies per §3 (SELECT player+family, write player-only).
3. **Backfill migration:** for every `user_preferences` row category `player` whose `data->'video_links'`
   is a non-empty array, insert one `video_links` row per element (`platform`, `url`, `title`,
   `position` = array index, `health_status='unknown'`), resolving `user_id` from the pref row and
   `family_unit_id` from the player's `family_members`. Idempotent (guard against re-insert).
4. Keep the JSONB `video_links` in place during transition (read-path cutover happens in B/C);
   a later cleanup migration drops it once both clients read the table. **Do not drop in Phase A.**

**Done when:** table + RLS live locally, backfill verified against seed data, no client reads it yet.

---

## 5. Phase B — Web (depends on A)

**Repo:** `recruiting-compass-web`

1. **API endpoints** for `video_links` CRUD (list/create/update/delete) with player-role + max-5 guards.
2. **Rules fixed:** `missingVideo.ts` + `videoLinkHealth.ts` read the table; `evaluate.post.ts`
   populates `context.videos` from `video_links` (remove the `as any` phantom cast). `missingVideo`
   also stops firing when the count comes from the real store.
3. **CTAs fixed:** `SuggestionCard.vue` routes `add_video`/`update_video` to the Athletics settings
   tab (real editor), not `/videos`.
4. **Settings editor migrated:** `PlayerDetailsAthleticsTab.vue` + `usePlayerDetailsForm.ts` read/write
   the table via the new API instead of the JSONB blob. Preserve max-5, platform select, `isParentRole`
   guard, add/remove UX.
5. **Health-check cron (Vercel):** scheduled job HTTP-HEADs each `url`, writes `health_status` +
   `last_health_check`. Web owns it. (URL reachability only; no deep platform API.)
6. **Comms template vars:** add `{{filmLinks}}`/`{{primaryFilmLink}}` to `templateVariables.ts` +
   resolver reads the table.
7. **Packet/profile cutover:** `recruitingPacketExport.ts`, `useRecruitingPacket.ts`, and public
   profile `film` (`server/api/public/profile/[slug].get.ts`) read `video_links` table.

**Done when:** rules fire off real data, CTA lands on the editor, editor round-trips the table, cron
updates health, packet/profile/comms surface links from the table.

---

## 6. Phase C — iOS (depends on A; parallel to B)

**Repo:** `recruiting-compass-ios` (source double-nested under `TheRecruitingCompass/TheRecruitingCompass/`)

1. **Model + service:** `VideoLink` Codable model + `VideoLinksManaging` protocol & impl doing Supabase
   CRUD on `video_links` (mirror `DocumentsServiceImpl`, snake_case CodingKeys, `@MainActor` VM /
   `Sendable` service, `nonisolated deinit`). NOT via preferences JSONB.
2. **Editor in player-details settings:** list + add/edit/delete rows, platform picker
   (Hudl/YouTube/Vimeo), max-5, player-only guard (mirror `isParentRole`), read-only health badge from
   `health_status`. Mirror `AddInteractionView` MVVM form pattern (`@Observable @MainActor` VM +
   `*CreateRequest`).
3. **Action-item CTA router (from scratch):** `actionType`→destination map per §3; make `ActionItemCard`
   tappable; cross-tab jump via `switchTab` + per-tab `NavigationPath` (`MainTabView.swift:69`). Unknown
   types render no CTA. `add_video`/`update_video` open the video editor in settings.
4. **Comms template var parity:** mirror `{{filmLinks}}`/`{{primaryFilmLink}}` in iOS
   `CommunicationTemplates` **if** its variable system supports insertion (verify during Phase C plan;
   if not, note as a follow-up rather than expand scope).

**Done when:** iOS player edits links (writes table), parents see them read-only, action-item CTAs
navigate to the right screens including video, health badges reflect the cron's `health_status`.

---

## 7. Non-goals (explicit)

- Do **not** merge/convert `documents` highlight_video **files** into `video_links`. Separate concept.
- No new top-level Videos tab on iOS. Editor lives in player-details settings.
- No deep platform integration (Hudl/YouTube APIs). Health = URL reachability only.
- Do **not** drop the JSONB `video_links` in Phase A; a later cleanup migration handles it after both
  clients read the table.

---

## 8. Risks / open questions

- **`context.videos` column shape:** rules read `id, health_status, title`. The new table supplies all
  three — verify no other consumer expects `athlete_id`/`file_url` from the old phantom query.
- **`user_id` vs `athlete_id`:** phantom query filtered by `athlete_id`; real ownership is the player's
  `user_id`. Confirm the player resolution in `evaluate.post.ts` matches the table's `user_id`.
- **Count-cap trigger vs concurrent inserts:** acceptable for max-5; app-side guard is primary UX, trigger
  is the backstop.
- **iOS comms variable system:** unverified whether iOS templates support variable insertion — Phase C
  plan resolves before committing to §6.4.
- **Health cron cadence + auth:** interval and service-role usage decided in Phase B plan.
- **Migration home:** authored under `recruiting-compass-web/supabase/migrations` (canonical). Local E2E
  stack must apply it before Phase C iOS work can seed video links.

---

## 9. Testing

- **A:** migration applies clean locally; backfill row-count matches JSONB element count; RLS unit checks
  (player write allowed, parent write denied, parent read allowed).
- **B:** rule unit tests fire on seeded broken/absent links; editor round-trip; cron marks a known-bad URL
  broken; packet/profile/comms render from table.
- **C:** service CRUD unit tests; editor VM tests (max-5, player-only); CTA-router mapping tests
  (each action_type → expected destination, unknown → nil); full unit suite stays green.
