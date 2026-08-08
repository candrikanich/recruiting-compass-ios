# Video Links — Phase A (Data Layer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the canonical `video_links` table (schema, RLS, count-cap, health columns) and backfill it from the existing `user_preferences.data.video_links` JSONB, with no client reading it yet.

**Architecture:** Two additive Supabase migrations in `recruiting-compass-web/supabase/migrations`: (1) schema + trigger + RLS, (2) idempotent backfill. The old JSONB store stays in place — cutover and its removal happen in Phases B/C. Verified against the local Supabase stack.

**Tech Stack:** PostgreSQL / Supabase migrations, `psql` against the local stack (`supabase start` / `supabase db reset`).

## Global Constraints

- Migration home: `recruiting-compass-web/supabase/migrations` (canonical). Filenames `YYYYMMDDHHMMSS_name.sql`; new files must sort AFTER `20260818000000_drop_users_phone.sql`. Use prefix `20260819000000`.
- Platforms allowed: `hudl`, `youtube`, `vimeo` (exact lowercase).
- `health_status` domain: `healthy`, `broken`, `unknown` (default `unknown`).
- Max **5** links per player (DB-enforced backstop).
- One player per family: `idx_player_one_family` guarantees a player `user_id` maps to exactly one `family_unit_id` (`role='player'`).
- RLS mirrors `documents`: SELECT = owner OR family; write = owning player only.
- **Do NOT** drop or alter the JSONB `user_preferences.data.video_links` in this phase.
- Local stack: run from `recruiting-compass-web/`. Reset with `supabase db reset` (re-applies all migrations + seed). Query with `psql "$(supabase status -o env | grep DB_URL | cut -d= -f2 | tr -d '\"')"` or the printed DB URL.

---

### Task 1: Schema + count-cap trigger + RLS

**Files:**
- Create: `recruiting-compass-web/supabase/migrations/20260819000000_video_links_table.sql`

**Interfaces:**
- Produces: table `public.video_links` with columns `id, user_id, family_unit_id, platform, url, title, position, health_status, last_health_check, created_at, updated_at`; trigger `video_links_max5_trg`; RLS policies. Phase B/C consume these exact names.

- [ ] **Step 1: Write the verification query (expected to fail before migration)**

Save as scratch `/tmp/vl_schema_check.sql`:
```sql
-- Fails until the table + trigger + policies exist.
SELECT 'table' AS obj WHERE to_regclass('public.video_links') IS NOT NULL
UNION ALL SELECT 'trigger' WHERE EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'video_links_max5_trg')
UNION ALL SELECT 'rls' WHERE EXISTS (SELECT 1 FROM pg_class WHERE relname='video_links' AND relrowsecurity);
```

- [ ] **Step 2: Run it against the current local DB — expect 0 rows**

Run (from `recruiting-compass-web/`):
```bash
psql "$SUPABASE_DB_URL" -f /tmp/vl_schema_check.sql
```
Expected: **0 rows** (nothing exists yet). If `SUPABASE_DB_URL` unset: `export SUPABASE_DB_URL=$(supabase status -o env | sed -n 's/^DB_URL=//p' | tr -d '"')`.

- [ ] **Step 3: Write the migration**

Create `20260819000000_video_links_table.sql`:
```sql
-- Phase A: canonical video_links table (promoted from user_preferences.data.video_links JSONB).
-- Additive only. JSONB store stays until Phase B/C cutover.

CREATE TABLE IF NOT EXISTS "public"."video_links" (
    "id"                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    "user_id"           uuid NOT NULL,               -- owning PLAYER (auth user)
    "family_unit_id"    uuid,                         -- parent read access
    "platform"          text NOT NULL,
    "url"               text NOT NULL,
    "title"             text,
    "position"          integer NOT NULL DEFAULT 0,   -- display order 0..4
    "health_status"     text NOT NULL DEFAULT 'unknown',
    "last_health_check" timestamptz,
    "created_at"        timestamptz NOT NULL DEFAULT now(),
    "updated_at"        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT "video_links_platform_check"
        CHECK (platform = ANY (ARRAY['hudl','youtube','vimeo'])),
    CONSTRAINT "video_links_health_status_check"
        CHECK (health_status = ANY (ARRAY['healthy','broken','unknown']))
);

CREATE INDEX IF NOT EXISTS "idx_video_links_user_id"        ON "public"."video_links" ("user_id");
CREATE INDEX IF NOT EXISTS "idx_video_links_family_unit_id" ON "public"."video_links" ("family_unit_id");
CREATE INDEX IF NOT EXISTS "idx_video_links_health"         ON "public"."video_links" ("health_status")
    WHERE health_status <> 'healthy';

-- keep updated_at fresh
CREATE OR REPLACE FUNCTION "public"."video_links_set_updated_at"() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER "video_links_updated_at_trg"
    BEFORE UPDATE ON "public"."video_links"
    FOR EACH ROW EXECUTE FUNCTION "public"."video_links_set_updated_at"();

-- max-5 backstop (app enforces UX; this guards the DB)
CREATE OR REPLACE FUNCTION "public"."video_links_enforce_max5"() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT count(*) FROM public.video_links WHERE user_id = NEW.user_id) >= 5 THEN
        RAISE EXCEPTION 'video_links limit reached (max 5 per user)';
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER "video_links_max5_trg"
    BEFORE INSERT ON "public"."video_links"
    FOR EACH ROW EXECUTE FUNCTION "public"."video_links_enforce_max5"();

-- RLS (mirrors documents: owner OR family read; owning player writes)
ALTER TABLE "public"."video_links" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "video_links_select_own_or_family" ON "public"."video_links"
    FOR SELECT USING (
        user_id = auth.uid()
        OR family_unit_id IN (
            SELECT family_unit_id FROM public.family_members WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "video_links_insert_owner_player" ON "public"."video_links"
    FOR INSERT WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (SELECT 1 FROM public.family_members
                    WHERE user_id = auth.uid() AND role = 'player')
    );

CREATE POLICY "video_links_update_owner_player" ON "public"."video_links"
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (SELECT 1 FROM public.family_members
                    WHERE user_id = auth.uid() AND role = 'player')
    );

CREATE POLICY "video_links_delete_owner_player" ON "public"."video_links"
    FOR DELETE USING (
        user_id = auth.uid()
        AND EXISTS (SELECT 1 FROM public.family_members
                    WHERE user_id = auth.uid() AND role = 'player')
    );
```

- [ ] **Step 4: Apply and re-run the check — expect 3 rows**

Run:
```bash
supabase db reset   # re-applies all migrations
psql "$SUPABASE_DB_URL" -f /tmp/vl_schema_check.sql
```
Expected: **3 rows** (`table`, `trigger`, `rls`).

- [ ] **Step 5: Verify the max-5 trigger fires**

Run (uses an arbitrary uuid; RLS bypassed as superuser via the local DB URL):
```bash
psql "$SUPABASE_DB_URL" -c "
DO \$\$
DECLARE u uuid := gen_random_uuid();
BEGIN
  FOR i IN 1..5 LOOP
    INSERT INTO public.video_links(user_id,platform,url,position)
    VALUES (u,'hudl','https://x/'||i,i);
  END LOOP;
  BEGIN
    INSERT INTO public.video_links(user_id,platform,url,position)
    VALUES (u,'hudl','https://x/6',6);
    RAISE EXCEPTION 'FAIL: 6th insert should have been blocked';
  EXCEPTION WHEN others THEN
    IF SQLERRM LIKE '%limit reached%' THEN RAISE NOTICE 'PASS: max5 enforced';
    ELSE RAISE; END IF;
  END;
  DELETE FROM public.video_links WHERE user_id = u;  -- cleanup
END \$\$;"
```
Expected: `NOTICE: PASS: max5 enforced`.

- [ ] **Step 6: Commit**

```bash
cd recruiting-compass-web
git add supabase/migrations/20260819000000_video_links_table.sql
git commit -m "feat(db): add video_links table with RLS, max-5 trigger, health columns"
```

---

### Task 2: Backfill from user_preferences JSONB

**Files:**
- Create: `recruiting-compass-web/supabase/migrations/20260819000100_video_links_backfill.sql`

**Interfaces:**
- Consumes: `public.video_links` (Task 1), `user_preferences` (`user_id, category, data`), `family_members` (`user_id, family_unit_id, role`).
- Produces: one `video_links` row per JSONB array element for every player pref that has links. Idempotent.

- [ ] **Step 1: Seed a known JSONB fixture + write the count check (expect mismatch before backfill)**

Run (creates a throwaway player pref with 2 links; capture the user_id):
```bash
psql "$SUPABASE_DB_URL" -c "
INSERT INTO public.user_preferences(user_id, category, data)
VALUES ('00000000-0000-0000-0000-0000000000aa','player',
  '{\"video_links\":[
     {\"platform\":\"hudl\",\"url\":\"https://hudl.com/a\",\"title\":\"A\"},
     {\"platform\":\"youtube\",\"url\":\"https://youtu.be/b\",\"title\":\"B\"}]}'::jsonb)
ON CONFLICT (user_id, category) DO UPDATE SET data = EXCLUDED.data;
SELECT count(*) AS backfilled FROM public.video_links
  WHERE user_id='00000000-0000-0000-0000-0000000000aa';"
```
Expected: `backfilled = 0` (nothing migrated yet).

- [ ] **Step 2: Write the backfill migration**

Create `20260819000100_video_links_backfill.sql`:
```sql
-- Phase A backfill: user_preferences.data.video_links JSONB -> video_links rows.
-- Idempotent: skips any (user_id,url) already present.
INSERT INTO public.video_links (user_id, family_unit_id, platform, url, title, position)
SELECT
    up.user_id,
    fm.family_unit_id,
    elem->>'platform'                              AS platform,
    elem->>'url'                                   AS url,
    NULLIF(elem->>'title','')                      AS title,
    (ord - 1)::int                                 AS position
FROM public.user_preferences up
CROSS JOIN LATERAL jsonb_array_elements(up.data->'video_links')
                   WITH ORDINALITY AS t(elem, ord)
LEFT JOIN public.family_members fm
       ON fm.user_id = up.user_id AND fm.role = 'player'
WHERE up.category = 'player'
  AND jsonb_typeof(up.data->'video_links') = 'array'
  AND elem->>'url' IS NOT NULL
  AND elem->>'platform' IN ('hudl','youtube','vimeo')
  AND NOT EXISTS (
        SELECT 1 FROM public.video_links vl
        WHERE vl.user_id = up.user_id AND vl.url = elem->>'url'
  );
```

- [ ] **Step 3: Apply and re-run the count check — expect match**

Run:
```bash
supabase db reset
# reset wipes the manual fixture from Step 1; re-seed then confirm idempotency by applying twice is moot (migration already ran during reset).
psql "$SUPABASE_DB_URL" -c "
INSERT INTO public.user_preferences(user_id, category, data)
VALUES ('00000000-0000-0000-0000-0000000000aa','player',
  '{\"video_links\":[
     {\"platform\":\"hudl\",\"url\":\"https://hudl.com/a\",\"title\":\"A\"},
     {\"platform\":\"youtube\",\"url\":\"https://youtu.be/b\",\"title\":\"B\"}]}'::jsonb)
ON CONFLICT (user_id, category) DO UPDATE SET data = EXCLUDED.data;"
# manually replay the backfill SQL for the fixture inserted AFTER reset:
psql "$SUPABASE_DB_URL" -f supabase/migrations/20260819000100_video_links_backfill.sql
psql "$SUPABASE_DB_URL" -c "
SELECT count(*) AS n, bool_and(health_status='unknown') AS all_unknown
FROM public.video_links WHERE user_id='00000000-0000-0000-0000-0000000000aa';"
```
Expected: `n = 2`, `all_unknown = t`.

- [ ] **Step 4: Verify idempotency (re-run does not duplicate)**

Run:
```bash
psql "$SUPABASE_DB_URL" -f supabase/migrations/20260819000100_video_links_backfill.sql
psql "$SUPABASE_DB_URL" -c "SELECT count(*) FROM public.video_links WHERE user_id='00000000-0000-0000-0000-0000000000aa';"
```
Expected: still `2` (NOT EXISTS guard blocks re-insert).

- [ ] **Step 5: Cleanup fixture**

```bash
psql "$SUPABASE_DB_URL" -c "
DELETE FROM public.video_links WHERE user_id='00000000-0000-0000-0000-0000000000aa';
DELETE FROM public.user_preferences WHERE user_id='00000000-0000-0000-0000-0000000000aa';"
```

- [ ] **Step 6: Commit**

```bash
cd recruiting-compass-web
git add supabase/migrations/20260819000100_video_links_backfill.sql
git commit -m "feat(db): backfill video_links from user_preferences JSONB (idempotent)"
```

---

### Task 3: RLS behavior verification (player writes, parent read-only)

**Files:**
- Create (scratch, not committed): `/tmp/vl_rls_check.sql`

**Interfaces:**
- Consumes: policies from Task 1. Confirms the write=player / read=family contract Phases B/C rely on.

- [ ] **Step 1: Write an RLS role-simulation check**

Save `/tmp/vl_rls_check.sql` (simulates a player and a parent in one family via `request.jwt.claim.sub`):
```sql
-- Setup: one family, one player, one parent.
DO $$
DECLARE fam uuid := gen_random_uuid();
        player uuid := gen_random_uuid();
        parent uuid := gen_random_uuid();
BEGIN
  INSERT INTO public.family_units(id) VALUES (fam) ON CONFLICT DO NOTHING;
  INSERT INTO public.family_members(family_unit_id,user_id,role)
    VALUES (fam,player,'player'),(fam,parent,'parent');
  -- seed one link owned by the player (superuser bypass)
  INSERT INTO public.video_links(user_id,family_unit_id,platform,url,position)
    VALUES (player,fam,'hudl','https://hudl.com/seed',0);

  PERFORM set_config('request.jwt.claim.sub', parent::text, true);
  SET LOCAL role authenticated;
  -- parent SELECT should see it
  IF (SELECT count(*) FROM public.video_links WHERE family_unit_id=fam) <> 1 THEN
     RAISE EXCEPTION 'FAIL: parent cannot read family link'; END IF;
  -- parent INSERT should be blocked by RLS
  BEGIN
    INSERT INTO public.video_links(user_id,family_unit_id,platform,url,position)
      VALUES (parent,fam,'hudl','https://hudl.com/parent',1);
    RAISE EXCEPTION 'FAIL: parent insert should be denied';
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    RAISE NOTICE 'PASS: parent write denied';
  END;

  RESET role;
  RAISE NOTICE 'PASS: parent read allowed';
  -- cleanup
  DELETE FROM public.video_links WHERE family_unit_id=fam;
  DELETE FROM public.family_members WHERE family_unit_id=fam;
  DELETE FROM public.family_units WHERE id=fam;
END $$;
```

- [ ] **Step 2: Run it — expect both PASS notices**

Run:
```bash
psql "$SUPABASE_DB_URL" -f /tmp/vl_rls_check.sql
```
Expected: `NOTICE: PASS: parent write denied` and `NOTICE: PASS: parent read allowed`, no `FAIL`.

> Note: if the local role for RLS simulation differs (`authenticated` vs `anon`), adjust `SET LOCAL role` to match the project's Supabase auth role. The assertion (parent reads, parent cannot write) is the contract — the role name is mechanism.

- [ ] **Step 3: No commit (verification only)**

This task ships no migration; it gates Phase B/C. If a policy assertion fails, fix the policy in `20260819000000_video_links_table.sql`, re-run `supabase db reset`, and re-verify Task 1 + Task 3.

---

## Self-Review

- **Spec coverage (design §4):** table+indexes (T1), count-cap trigger (T1), RLS player/family (T1+T3), backfill idempotent (T2), JSONB left intact (no drop anywhere) ✓.
- **Placeholder scan:** no TBD/TODO; every SQL step has concrete content ✓.
- **Type consistency:** table/column/trigger/policy names identical across T1→T3 (`video_links`, `video_links_max5_trg`, `health_status`) ✓.
- **Gap noted:** exact Supabase auth role name for RLS simulation is environment-dependent (flagged inline in T3). Not a blocker — assertion is explicit.

## Execution Handoff

Phase A is self-contained (DB only). On completion, Phase B (web) and Phase C (iOS) can proceed in parallel against the live table. Plans for B and C are authored after A verifies green.
