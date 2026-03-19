# E2E Test Environment Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unlock 356 currently-skipped E2E tests by creating a test Supabase user, configuring the Xcode scheme with credentials, and seeding the required test data.

**Architecture:** All E2E tests hardcode `test@example.com`/`TestPassword1` and read `SUPABASE_URL` + `SUPABASE_ANON_KEY` from `ProcessInfo.processInfo.environment` at launch. A single SQL seed script creates the test user's family, schools, coaches, interactions, events, offers, performance metrics, notifications, and documents in an idempotent way. The scheme env vars wire these to the test runner.

**Tech Stack:** Supabase (Auth, SQL), Xcode scheme environment variables, SQL seed script

---

## Scope Notes

This plan covers **Phase 1** of fixing the 418 skipped tests:
- **356 E2E tests** in `TheRecruitingCompassUITests` — fixed here (need Supabase user + data)
- **62 UIHostingController accessibility unit tests** — NOT fixed here, tracked as Plan B (`2026-03-19-uihostingcontroller-accessibility-tests.md`)

The 62 UIHostingController tests skip because SwiftUI doesn't expose accessibility labels via `UIHostingController` in unit tests. They always skip regardless of Supabase configuration and need a different solution.

---

## Skip Reason Breakdown (the 356)

| Skip message | Count | Fix |
|---|---|---|
| "Login failed - Supabase may not be configured" | 106 | Create test user + scheme env vars |
| "Login failed" | 23 | Same |
| "Content did not load" | 40 | Seed domain data |
| "Screen did not load" | 23 | Seed data + auth |
| "No notifications content loaded" | 11 | Seed notifications |
| "Requires School Detail loading integration" | 8 | Seed schools with coaches |
| "Recent Activity widget not found" | 5 | Seed activity feed data |
| "Offers screen not reachable" | 5 | Seed offers |
| "Family code not loaded" | 5 | Create family unit |
| "No offers available…" | 9 | Seed offers |
| "No metrics available" | 3 | Seed performance metrics |
| "No duplicate detected" | 3 | Seed duplicate school |
| "No data to export" | 3 | Seed exportable data |
| "No activities available…" | 15 | Seed activity events |
| Other data-related | ~67 | Seed domain data |

---

## Files

**Created:**
- `supabase/seed-test-data.sql` — Idempotent SQL script to seed all test data
- `scripts/run-e2e-tests.sh` — Convenience script to run E2E tests with env vars from `.env.test`
- `.env.test.example` — Template for test credentials (committed, not `.env.test` itself)

**Modified:**
- Xcode scheme `TheRecruitingCompass` → Run → Arguments → Environment Variables (manual, not in git)

---

## Task 1: Verify test credentials pattern

Before creating anything, confirm how credentials flow to the app.

**Files:**
- Read: `TheRecruitingCompass/TheRecruitingCompassUITests/Helpers/XCUITestHelpers.swift`

- [ ] **Step 1: Check the launch pattern in a representative test**

```bash
grep -n "launchEnvironment\|SUPABASE\|loginAsParent" \
  TheRecruitingCompass/TheRecruitingCompassUITests/Features/Offers/OffersListE2ETests.swift | head -10
```

Expected output confirms:
```
app.launchEnvironment = ["SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "", ...]
app.loginAsParent(email: "test@example.com", password: "TestPassword1")
```

- [ ] **Step 2: Confirm how the app reads these env vars**

```bash
grep -rn "SUPABASE_URL\|SUPABASE_ANON_KEY" \
  TheRecruitingCompass/TheRecruitingCompass/Core/ --include="*.swift" | head -10
```

This confirms the env vars are read by `SupabaseManager` at launch, overriding the scheme-compiled values during tests.

---

## Task 2: Create the test user in Supabase

This is a **manual step** in the Supabase Dashboard. Cannot be automated from iOS.

**Prerequisites:** Access to the Supabase project dashboard.

- [ ] **Step 1: Navigate to Supabase Dashboard → Authentication → Users**

Go to: `https://supabase.com/dashboard/project/<your-project>/auth/users`

- [ ] **Step 2: Create the test parent user**

Click "Add user" → "Create new user":
- Email: `test@example.com`
- Password: `TestPassword1`
- ✅ Auto Confirm User (skip email verification)

- [ ] **Step 3: Note the user UUID**

After creation, copy the UUID for the new user. You'll need it in the seed SQL.

Format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

Save it — you'll use it as `TEST_USER_ID` in Task 4.

- [ ] **Step 4: Verify the user can sign in**

In Supabase Dashboard → SQL Editor, test the credentials:
```sql
-- This won't work in SQL editor directly; use the Supabase Auth API to test.
-- Instead, skip to Task 3 to configure the scheme, then run a single test
-- to verify login works before seeding.
```

---

## Task 3: Configure the Xcode scheme env vars

The Xcode test scheme must pass `SUPABASE_URL` and `SUPABASE_ANON_KEY` as environment variables. These are NOT committed to git (they contain credentials).

**Prerequisites:** `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase project settings.

Where to find them: Supabase Dashboard → Project Settings → API → `URL` and `anon public` key.

- [ ] **Step 1: Open the scheme editor**

In Xcode:
1. `Product` → `Scheme` → `Edit Scheme` (or `Cmd+<`)
2. Select `TheRecruitingCompass` scheme
3. Click `Test` in the left sidebar
4. Click `Arguments` tab

- [ ] **Step 2: Add environment variables**

Under "Environment Variables", click `+` and add:

| Name | Value |
|---|---|
| `SUPABASE_URL` | `https://your-project-id.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJ...` (your anon key) |

- [ ] **Step 3: Ensure the scheme is NOT shared**

The scheme with credentials should be a LOCAL user scheme (not in git).

Check: In Scheme editor, uncheck "Shared" if checked. Local schemes are stored in:
`TheRecruitingCompass/TheRecruitingCompass.xcodeproj/xcuserdata/<username>.xcuserdatad/xcschemes/`

These are gitignored.

- [ ] **Step 4: Create `.env.test.example` for documentation**

Create `scripts/.env.test.example`:

```bash
# Copy this to .gitignored scripts/.env.test and fill in your values
# Used by scripts/run-e2e-tests.sh for CI/manual runs
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
TEST_PARENT_EMAIL=test@example.com
TEST_PARENT_PASSWORD=TestPassword1
```

Add `scripts/.env.test` to `.gitignore`:
```bash
echo "scripts/.env.test" >> .gitignore
```

- [ ] **Step 5: Verify login-only tests now pass**

Run just the auth-dependent tests to verify credentials work before seeding data:

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/AddCoachE2ETests \
  2>&1 | grep -E "passed|failed|skipped" | tail -10
```

Expected: Some tests pass (login works), some skip (missing data), none crash.

- [ ] **Step 6: Commit the `.env.test.example` and `.gitignore` update**

```bash
git add scripts/.env.test.example .gitignore
git commit -m "chore(tests): add E2E test env var template"
```

---

## Task 4: Write the seed SQL script

Create an idempotent SQL script that seeds all required test data for `test@example.com`. Run it any time to reset to a known state.

**Files:**
- Create: `supabase/seed-test-data.sql`

- [ ] **Step 1: Get the test user UUID from Supabase**

```sql
-- Run in Supabase Dashboard → SQL Editor
SELECT id FROM auth.users WHERE email = 'test@example.com';
```

Copy the UUID. Replace `'<TEST_USER_UUID>'` in the script below with this value.

- [ ] **Step 2: Create `supabase/seed-test-data.sql`**

```sql
-- =============================================================================
-- E2E Test Data Seed Script
-- =============================================================================
-- Idempotent: safe to run multiple times. Uses ON CONFLICT DO NOTHING / UPDATE.
-- Run in: Supabase Dashboard → SQL Editor
--
-- Prerequisites:
--   1. Create test@example.com user in Auth dashboard (Auto Confirm)
--   2. Replace <TEST_USER_UUID> below with the actual UUID from:
--      SELECT id FROM auth.users WHERE email = 'test@example.com';
-- =============================================================================

DO $$
DECLARE
  v_user_id UUID := '<TEST_USER_UUID>';  -- ← REPLACE THIS
  v_family_id UUID;
  v_school1_id UUID := gen_random_uuid();
  v_school2_id UUID := gen_random_uuid();
  v_coach1_id UUID := gen_random_uuid();
  v_coach2_id UUID := gen_random_uuid();
  v_event1_id UUID := gen_random_uuid();
  v_interaction1_id UUID := gen_random_uuid();
  v_offer1_id UUID := gen_random_uuid();
  v_offer2_id UUID := gen_random_uuid();
  v_metric1_id UUID := gen_random_uuid();
  v_metric2_id UUID := gen_random_uuid();
  v_doc1_id UUID := gen_random_uuid();
BEGIN

-- -----------------------------------------------------------------------
-- 1. User profile (raw user metadata)
-- -----------------------------------------------------------------------
UPDATE auth.users
SET raw_user_meta_data = jsonb_build_object(
  'full_name', 'Test Parent',
  'role', 'parent'
)
WHERE id = v_user_id;

-- -----------------------------------------------------------------------
-- 2. Family unit
-- -----------------------------------------------------------------------
-- Check if user already has a family
SELECT fu.id INTO v_family_id
FROM family_units fu
JOIN family_members fm ON fm.family_unit_id = fu.id
WHERE fm.user_id = v_user_id
LIMIT 1;

IF v_family_id IS NULL THEN
  v_family_id := gen_random_uuid();
  INSERT INTO family_units (id, name, created_at, updated_at)
  VALUES (v_family_id, 'Test Family', now(), now());

  INSERT INTO family_members (id, family_unit_id, user_id, role, added_at)
  VALUES (gen_random_uuid(), v_family_id, v_user_id, 'parent', now())
  ON CONFLICT DO NOTHING;
END IF;

-- -----------------------------------------------------------------------
-- 3. Schools (need ≥2: one for normal tests, one for duplicate detection)
-- -----------------------------------------------------------------------
INSERT INTO schools (
  id, family_unit_id, name, division, conference,
  location, state, city, recruiting_status, created_at, updated_at
) VALUES
  (v_school1_id, v_family_id, 'State University', 'D1', 'Big Ten',
   'Columbus, OH', 'OH', 'Columbus', 'considering', now(), now()),
  (v_school2_id, v_family_id, 'State University', 'D1', 'Big Ten',
   'Columbus, OH', 'OH', 'Columbus', 'interested', now(), now())
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------
-- 4. Coaches (attached to school1)
-- -----------------------------------------------------------------------
INSERT INTO coaches (
  id, family_unit_id, school_id, first_name, last_name, title,
  email, phone, position, created_at, updated_at
) VALUES
  (v_coach1_id, v_family_id, v_school1_id, 'John', 'Smith',
   'Head Coach', 'jsmith@stateuniversity.edu', '614-555-0101',
   'Head Coach', now(), now()),
  (v_coach2_id, v_family_id, v_school1_id, 'Jane', 'Doe',
   'Assistant Coach', 'jdoe@stateuniversity.edu', '614-555-0102',
   'Assistant Coach', now(), now())
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------
-- 5. Interactions (coach interactions for school1)
-- -----------------------------------------------------------------------
INSERT INTO interactions (
  id, family_unit_id, school_id, coach_id, user_id,
  type, direction, sentiment, subject, content,
  occurred_at, created_at, updated_at
) VALUES
  (v_interaction1_id, v_family_id, v_school1_id, v_coach1_id, v_user_id,
   'email', 'inbound', 'positive',
   'Campus Visit Invitation',
   'Coach Smith invited us to an official campus visit next month.',
   now() - interval '3 days', now(), now())
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------
-- 6. Events
-- -----------------------------------------------------------------------
INSERT INTO events (
  id, family_unit_id, title, event_type, start_date, end_date,
  location, notes, created_at, updated_at
) VALUES
  (v_event1_id, v_family_id, 'Spring Showcase', 'showcase',
   now() + interval '7 days', now() + interval '7 days' + interval '4 hours',
   'Columbus, OH', 'Annual spring showcase event.',
   now(), now())
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------
-- 7. Offers
-- -----------------------------------------------------------------------
INSERT INTO offers (
  id, family_unit_id, school_id, coach_id,
  scholarship_type, scholarship_percentage, annual_value,
  tuition, room_board, books_fees, other_aid,
  offer_date, expiration_date, status, notes,
  created_at, updated_at
) VALUES
  (v_offer1_id, v_family_id, v_school1_id, v_coach1_id,
   'athletic', 100, 55000,
   32000, 18000, 2000, 3000,
   now() - interval '30 days', now() + interval '60 days',
   'active', 'Full scholarship offer.',
   now(), now()),
  (v_offer2_id, v_family_id, v_school2_id, NULL,
   'athletic', 75, 41250,
   32000, 18000, 2000, 0,
   now() - interval '15 days', now() + interval '45 days',
   'active', '75% scholarship offer.',
   now(), now())
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------
-- 8. Performance metrics
-- -----------------------------------------------------------------------
INSERT INTO performance_metrics (
  id, user_id, metric_type, value, unit,
  recorded_date, verified, notes, created_at, updated_at
) VALUES
  (v_metric1_id, v_user_id, 'velocity', 87.5, 'mph',
   now() - interval '7 days', true, 'Peak velocity reading.',
   now(), now()),
  (v_metric2_id, v_user_id, 'velocity', 85.0, 'mph',
   now() - interval '14 days', false, NULL,
   now(), now())
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------
-- 9. Documents
-- -----------------------------------------------------------------------
INSERT INTO documents (
  id, family_unit_id, school_id, user_id,
  title, document_type, file_url,
  created_at, updated_at
) VALUES
  (v_doc1_id, v_family_id, v_school1_id, v_user_id,
   'Transcript 2026', 'transcript',
   'https://example.com/placeholder-transcript.pdf',
   now(), now())
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------
-- 10. Notifications
-- -----------------------------------------------------------------------
INSERT INTO notifications (
  id, user_id, title, body, notification_type,
  is_read, created_at
) VALUES
  (gen_random_uuid(), v_user_id,
   'New offer from State University',
   'Coach Smith sent you an offer. Tap to review.',
   'offer', false, now() - interval '1 day'),
  (gen_random_uuid(), v_user_id,
   'Interaction logged',
   'Your recent email with Coach Smith has been logged.',
   'interaction', true, now() - interval '3 days')
ON CONFLICT DO NOTHING;

RAISE NOTICE 'Seed complete. Family ID: %', v_family_id;
END $$;
```

- [ ] **Step 3: Verify column names match the actual schema**

Before running, verify a few key columns exist. In Supabase SQL Editor:

```sql
-- Check schools table structure
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'schools'
ORDER BY ordinal_position;
```

Adjust column names in the seed script if any don't match.
Key things to check:
- `schools.recruiting_status` — might be `status` or `school_status`
- `coaches.position` — might be `role` or `title`
- `interactions.type` vs `interaction_type`
- `offers.scholarship_type` and columns — verify against schema
- `documents.document_type` — might be `type`
- `notifications.notification_type` — might be `type`

- [ ] **Step 4: Commit the seed script**

```bash
git add supabase/seed-test-data.sql
git commit -m "chore(tests): add E2E test data seed script"
```

---

## Task 5: Run the seed script

- [ ] **Step 1: Open Supabase Dashboard → SQL Editor**

Navigate to: `https://supabase.com/dashboard/project/<your-project>/sql/new`

- [ ] **Step 2: Replace the placeholder UUID**

Before pasting the script, get the real UUID:

```sql
SELECT id FROM auth.users WHERE email = 'test@example.com';
```

Copy the UUID (e.g., `a1b2c3d4-e5f6-...`).

- [ ] **Step 3: Paste the seed script with the real UUID**

Replace `'<TEST_USER_UUID>'` in the `DO $$ DECLARE` block with the real UUID, then run.

Expected output: `Seed complete. Family ID: <some-uuid>`

- [ ] **Step 4: Verify data was created**

```sql
-- Quick sanity check
SELECT
  (SELECT count(*) FROM family_units fu JOIN family_members fm ON fm.family_unit_id = fu.id
   WHERE fm.user_id = (SELECT id FROM auth.users WHERE email = 'test@example.com')) AS family_count,
  (SELECT count(*) FROM schools WHERE family_unit_id = (
    SELECT fu.id FROM family_units fu JOIN family_members fm ON fm.family_unit_id = fu.id
    WHERE fm.user_id = (SELECT id FROM auth.users WHERE email = 'test@example.com')
    LIMIT 1
  )) AS school_count,
  (SELECT count(*) FROM offers WHERE family_unit_id = (
    SELECT fu.id FROM family_units fu JOIN family_members fm ON fm.family_unit_id = fu.id
    WHERE fm.user_id = (SELECT id FROM auth.users WHERE email = 'test@example.com')
    LIMIT 1
  )) AS offer_count;
```

Expected: `family_count=1, school_count=2, offer_count=2`

---

## Task 6: Run the full test suite and measure progress

- [ ] **Step 1: Run the full E2E test suite**

```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  > /tmp/e2e_after_seed.log 2>&1

echo "Passed: $(grep "^Test case.*passed" /tmp/e2e_after_seed.log | wc -l | tr -d ' ')"
echo "Failed: $(grep "^Test case.*failed" /tmp/e2e_after_seed.log | wc -l | tr -d ' ')"
echo "Skipped: $(grep "^Test case.*skipped" /tmp/e2e_after_seed.log | wc -l | tr -d ' ')"
```

**Target:** 0 failures, skips reduced from 418 to ≤62 (UIHostingController tests).

- [ ] **Step 2: Identify any remaining data-related skips**

```bash
grep "^Test case.*skipped" /tmp/e2e_after_seed.log | awk -F"'" '{print $2}' | cut -d. -f1 | sort | uniq -c | sort -rn | head -20
```

If specific test classes still skip, add the required data to `seed-test-data.sql` for those tables and re-run.

- [ ] **Step 3: Patch the seed script for any remaining gaps**

For each remaining data-dependent skip, identify the required table/data and add an INSERT to `seed-test-data.sql`. Common gaps to watch for:

| Skip message | Table to seed |
|---|---|
| "No activities available" | `activity_events` or `activity_feed` (check table name) |
| "Tasks tab not reachable" | `tasks` or `user_tasks` |
| "No stats available" | Ensure `performance_metrics` has multiple metric types |
| "Requires test data creation via API" | May need to use Supabase service-role key for restricted tables |
| "Name field not found" | Navigation issue — verify school/coach data exists |

- [ ] **Step 4: Commit final seed script**

```bash
git add supabase/seed-test-data.sql
git commit -m "chore(tests): fix E2E test data seed for remaining gaps"
```

---

## Task 7: Add the convenience test runner script

This makes it easy to run E2E tests from the command line with credentials, and is useful for CI.

**Files:**
- Create: `scripts/run-e2e-tests.sh`

- [ ] **Step 1: Create `scripts/run-e2e-tests.sh`**

```bash
#!/usr/bin/env bash
# run-e2e-tests.sh — Run the full E2E test suite with Supabase credentials.
# Usage: ./scripts/run-e2e-tests.sh
# Requires: scripts/.env.test with SUPABASE_URL and SUPABASE_ANON_KEY

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.test"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found."
  echo "Copy scripts/.env.test.example to scripts/.env.test and fill in credentials."
  exit 1
fi

source "$ENV_FILE"

cd "$SCRIPT_DIR/../TheRecruitingCompass"

echo "Running E2E tests against: $SUPABASE_URL"

xcodebuild test \
  -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -testenv SUPABASE_URL="$SUPABASE_URL" \
  -testenv SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  "$@" \
  2>&1 | tee /tmp/e2e_run.log

echo ""
echo "=== Results ==="
echo "Passed:  $(grep '^Test case.*passed' /tmp/e2e_run.log | wc -l | tr -d ' ')"
echo "Failed:  $(grep '^Test case.*failed' /tmp/e2e_run.log | wc -l | tr -d ' ')"
echo "Skipped: $(grep '^Test case.*skipped' /tmp/e2e_run.log | wc -l | tr -d ' ')"
```

Note: The `-testenv` flag passes env vars to the test runner (available in Xcode 14+). This overrides any scheme-level env vars and works without modifying the scheme.

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/run-e2e-tests.sh
git add scripts/run-e2e-tests.sh scripts/.env.test.example
git commit -m "chore(tests): add E2E test runner script with credential injection"
```

---

## Task 8: Handle tests with destructive mutations

Some E2E tests **delete** or **edit** data (e.g., `OfferDetailDeleteE2ETests`, `SchoolDetailDeleteE2ETests`). After they run, subsequent runs will find no data to test.

**Fix: Make the seed script truly idempotent by using fixed UUIDs.**

- [ ] **Step 1: Identify destructive tests**

```bash
grep -rn "delete\|Delete\|remove\|Remove" \
  TheRecruitingCompass/TheRecruitingCompassUITests/ \
  --include="*.swift" | grep "E2ETests" | grep "swipe\|tap.*delete\|deleteButton" | head -10
```

- [ ] **Step 2: Use deterministic UUIDs in seed script**

Replace `gen_random_uuid()` with fixed UUIDs for objects that might be deleted, so re-running the seed restores them:

```sql
-- Example: fixed UUIDs for deletable objects
v_offer1_id UUID := 'a0000001-e2e0-4000-8000-000000000001';
v_school1_id UUID := 'a0000001-e2e0-4000-8000-000000000002';
```

Then use `ON CONFLICT (id) DO UPDATE SET ...` instead of `ON CONFLICT DO NOTHING` for those rows, so they're restored even if deleted.

```sql
INSERT INTO offers (id, family_unit_id, ...)
VALUES (v_offer1_id, v_family_id, ...)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  updated_at = EXCLUDED.updated_at;
```

- [ ] **Step 3: Update the seed script and commit**

```bash
git add supabase/seed-test-data.sql
git commit -m "chore(tests): use fixed UUIDs in seed script for destructive test recovery"
```

---

## Summary of Expected Outcome

After completing this plan:

| State | Before | After |
|---|---|---|
| Passing | 3,486 | ~3,800+ |
| Failing | 0 | 0 |
| Skipping | 418 | ≤62 (UIHostingController only) |

The 62 remaining UIHostingController accessibility test skips are addressed in a separate plan: `planning/2026-03-19-uihostingcontroller-accessibility-tests.md`.

---

## Unresolved Questions

1. **What Supabase project should be used for testing?** The same project as production, or a dedicated test project? Using production risks test data contaminating real user data. A separate project is cleaner but requires maintaining two schema migrations.

2. **What is the exact schema for `offers`?** The column names in the seed script (e.g., `scholarship_type`, `annual_value`) are inferred from the iOS model. Verify against the actual table before running.

3. **Does `activity_events`/`activity_feed` exist as a table, or is it computed?** Several tests skip with "No activities available". If activity feed is derived from other tables (interactions, events, etc.) rather than a standalone table, seeding the other tables should be sufficient.

4. **Are there any RLS policies that prevent inserting test data directly via SQL?** Some tables have `SECURITY DEFINER` functions and strict RLS. Check RLS for `schools`, `coaches`, `offers` before running the seed — you may need to use `SET LOCAL role = service_role;` at the start of the transaction.

5. **Should CI run E2E tests?** If yes, the `SUPABASE_URL` and `SUPABASE_ANON_KEY` need to be added as GitHub Actions secrets and the workflow needs to be updated with `-testenv` flags.
