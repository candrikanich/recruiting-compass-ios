# Family-Shared Player Profile — parent can view AND edit the athlete's profile

**Date:** 2026-08-09
**Bug origin:** Family FAM-MA9G7D. Parent opens Player Profile, sees none of the player's (Owen's) data.
**Supabase project:** `xpxzhqghxecsjhvklsqg` (shared by web + iOS).

---

## Root cause (confirmed with live data)

Player profile = `user_preferences` row, `category='player'`, one row per `user_id`. Each family
member has their OWN row:

| Role | user_id | player row |
|---|---|---|
| parent | `06869a04…` | stale, 2025-12-27, partial |
| player (Owen) | `3d97c4dc…` | rich, 2026-08-08 — the real profile |

- **iOS** (`PreferenceServiceImpl.fetchPreferences`, `PreferenceServiceImpl.swift:144,149`) filters
  `user_id = auth.uid()` (viewer). Reads AND writes viewer's own row. No athlete awareness.
- **iOS RLS** (`user_preferences` SELECT/INSERT/UPDATE) = `auth.uid() = user_id`. Even a fixed
  client cannot touch the athlete's row.
- **Web** GET `/api/user/preferences/[category]` DOES redirect parent→athlete for
  `PLAYER_OWNED_CATEGORIES = {location, player, school}` (`[category].get.ts:82-95`). But web POST
  (`[category].post.ts:60-70`) always upserts `user_id: user.id` — **parent edits hit parent's own
  row.** Web read works, web write is broken.
- Web uses service-role admin client everywhere → table RLS is bypassed for web.

## Design decision

**Canonical player profile = the player-role member's row.** Every family member (parent + player)
reads and writes THAT row. Different clients need different enforcement:

- iOS (direct DB, RLS on) → **new RLS policies** granting family members access to the player's
  `player`-category row + client must **target the athlete's user_id**.
- Web (service-role, RLS off) → **app-code fix**: POST must redirect parent→athlete, same as GET.

---

## Phase 1 — DB: RLS + data reconciliation (shared, do first)

Migration in **web repo** `supabase/migrations/` (canonical DB migrations live there), then apply to
project `xpxzhqghxecsjhvklsqg`.

### 1a. Helper (SECURITY DEFINER, non-recursive — reuses existing `get_user_family_ids()`)
```sql
create or replace function public.can_access_family_player_prefs(target_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from family_members them
    where them.user_id = target_user
      and them.role = 'player'
      and them.family_unit_id in (select family_unit_id from get_user_family_ids())
  );
$$;
```

### 1b. Additive policies — scoped to the three player-owned categories (`player`, `location`, `school`)
Do NOT expose notifications / dashboard-customization / etc. — those stay private.
```sql
-- DECIDED: player + location + school (full web parity with PLAYER_OWNED_CATEGORIES)
create policy "Family can view player-owned prefs" on user_preferences for select
  using (category in ('player','location','school') and can_access_family_player_prefs(user_id));
create policy "Family can update player-owned prefs" on user_preferences for update
  using (category in ('player','location','school') and can_access_family_player_prefs(user_id))
  with check (category in ('player','location','school') and can_access_family_player_prefs(user_id));
create policy "Family can insert player-owned prefs" on user_preferences for insert
  with check (category in ('player','location','school') and can_access_family_player_prefs(user_id));
```
Existing self-scoped policies stay (cover all other categories + player-self). Policies OR together.

### 1c. Data reconciliation — MERGE THEN DELETE (⚠️ mutates prod data — run in a transaction)
**DECIDED: merge-then-delete.** For each parent-role member holding a `player`/`location`/`school`
row (per category):
- if the linked athlete already has that category row → **delete** the parent's stale row;
- if the athlete has none → **copy** parent's data into a new athlete-owned row first, then delete
  the parent's.

(For FAM-MA9G7D: Owen already has all rows newer/richer → parent's Dec rows are deleted.)
Do this as a one-off migration/script over all families, idempotent, wrapped in a transaction.

---

## Phase 2 — iOS client (this repo)

1. **`PreferenceManaging`** — add athlete targeting without breaking other callers:
   - Real requirement: `fetchPreferences<T>(category:, userId: String?)` /
     `savePreferences<T>(category:, userId: String?, data:)`.
   - Protocol extension convenience `…(category:)` forwarding `userId: nil` → all existing callers
     (school/notification/home-location VMs) unchanged.
2. **`PreferenceServiceImpl`** — use passed `userId ?? getCurrentUserId()` in all filters/payloads.
3. **`PlayerDetailsViewModel`** — hold a `targetUserId`; load & save against it. **Remove
   `isReadOnly = (userRole == .parent)`** → parents edit. (`saveDetails`/`markChanged` guards drop.)
4. **`PlayerDetailsView` / call sites** — resolve target =
   `FamilyManager.shared.selectedAthlete?.userId ?? authManager.user?.id` (mirrors VideoLinks,
   `SettingsView.swift:243`). Pass into the VM. Applies to `SettingsView:229` and `ProfileView:38`.
5. **Tests** — update `MockPreferenceManager` + `PreferencePreviewMock` to new signature; update
   `PlayerDetailsViewModelTests` (drop read-only-parent expectations, add athlete-target coverage);
   `PreferenceServiceTests`.

## Phase 3 — Web client (web repo)

1. **`[category].post.ts`** — redirect parent→athlete for `PLAYER_OWNED_CATEGORIES` before upsert
   (reuse `getLinkedAthleteId`), mirroring the GET path. Write to the athlete's row.
2. Reconcile the legacy `player-details.patch.ts` (`assertNotParent`, "read-only view") and
   `profile-field.patch.ts` / `canMutateAthleteData` (returns false for parents) with the new
   parent-can-edit direction. Flag: are these used by the live form? (Explorer says the form uses
   `player`, not `player_details`.) Likely leave unless they gate a used field.

## Phase 4 — Photo (INCLUDED — decided in scope)

Currently iOS photo is **in-memory only** (`PlayerDetailsViewModel.uploadProfilePhoto:142`) — never
persisted anywhere, no DB field. Web stores it in `users.profile_photo_url` + Storage bucket
`profile-photos`, keyed to logged-in user (no athlete redirect). Target: family-shared photo on the
athlete's record.

### 4a. DB (migration in web repo, apply to shared project)
- **Read:** family members must read the athlete's `users.profile_photo_url`. Add a family SELECT
  path — prefer a SECURITY DEFINER RPC `get_athlete_profile_photo(athlete uuid)` (or a narrow
  family SELECT policy on `users`) so we don't broaden general `users` read access.
- **Write:** parent must set the athlete's photo. Prefer SECURITY DEFINER RPC
  `set_athlete_profile_photo(athlete uuid, url text)` that checks
  `can_access_family_player_prefs(athlete)` — avoids a broad UPDATE policy on `users` (column-level
  restriction isn't native to RLS).
- **Storage:** bucket `profile-photos` RLS must allow a family member to upload/delete under the
  athlete's prefix `<athleteUserId>/…` (policy keyed via `can_access_family_player_prefs`).

### 4b. iOS
- Real Storage upload to `profile-photos/<athleteUserId>/…` (mirror `InteractionsServiceImpl`
  storage pattern), then persist via `set_athlete_profile_photo`. Load via the read path on profile
  open. Replace the in-memory-only `uploadProfilePhoto`/`deleteProfilePhoto`.

### 4c. Web
- Redirect photo read/write to the athlete in `useProfile.ts` (upload path, `getPublicUrl`, the
  `users.profile_photo_url` update, and delete) when a parent is viewing. Reuse `getLinkedAthleteId`.

---

## Verification
- SQL: as parent, `select` + `update` athlete's `player` row succeeds; other categories still blocked.
- iOS: parent opens Player Profile → sees Owen's data; edits save to Owen's row; player self-edit
  unchanged. `xcodebuild test` affected classes green.
- Web: parent edit persists to athlete's row.
- Re-check FAM-MA9G7D: both members see the single canonical (Owen's) profile.

## STATUS: Phases 1–4 COMPLETE (2026-08-09)
- **Phase 1 (DB)** — applied to prod `xpxzhqghxecsjhvklsqg`: helper `can_access_family_player_prefs`,
  additive RLS on `user_preferences` (player/location/school), merge-then-delete reconciliation
  (4 rows). Verified: parent reads/writes athlete rows; private categories + strangers blocked.
  Migrations: `20260821000000_family_shared_player_prefs_rls.sql`,
  `20260821000100_reconcile_parent_player_owned_prefs.sql` (in web repo).
- **Phase 2 (iOS)** — `PreferenceManaging.userId` targeting; `PlayerDetailsViewModel` loads/saves
  athlete row; parents edit. Build + tests green.
- **Phase 3 (web)** — `server/utils/playerOwnedPreferences.ts`; GET+POST redirect parent→athlete.
  Typecheck + unit tests green.
- **Phase 4 (photo)** — DB: `set_athlete_profile_photo` RPC (self OR family-athlete) +
  storage family-write policies (`20260821000200`, `..._allow_self`). iOS: `ProfilePhotoService`
  persists via RPC + `currentPhotoURL`; Player Profile shows/edits athlete's real photo. Web:
  `useProfilePhoto` targets athlete via RPC; player-details un-gated (parents edit); e2e restriction
  spec inverted. All verified.
- **Remaining gap:** iOS `SchoolPreferences`/`HomeLocation` VMs still self-scope (RLS + web allow
  parent for location/school; iOS client doesn't thread `targetUserId` yet). Player-profile bug fixed.
- **Not committed.** iOS on `main` checkout (needs a branch); web on `feat/family-shared-player-profile`.

## Decisions locked (2026-08-09)
1. Reconciliation: **merge-then-delete** parent-role rows (1c).
2. Categories: **player + location + school** (full web parity).
3. Photo: **included** (Phase 4).

## Remaining note
- Multi-athlete families: iOS uses `selectedAthlete`; web derives the single player-role member
  (no switcher). Fine for single-athlete families; multi-athlete web needs a switcher later.
