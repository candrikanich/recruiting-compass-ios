# E2E Test Environment Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unlock ~356 currently-skipping iOS E2E tests by creating a `test@example.com` iOS test user + seed data, wiring the iOS CI to run UITests, and making local development easy via an Xcode scheme.

**Architecture:** The web app (`recruiting-compass-web`) already has `createTestAccounts()` + `db:seed:test` infrastructure using `@supabase/supabase-js` with the service role key. This plan mirrors that pattern in a new iOS-side `scripts/seed-e2e.ts` script. The iOS CI workflow gains a seed step + UITest step. Both repos share the same single Supabase project; the iOS user (`test@example.com`) is separate from the web test users (`player@test.com`, `parent@test.com`).

**Tech Stack:** Node.js + `tsx`, `@supabase/supabase-js`, GitHub Actions, Xcode scheme env vars

---

## Context

| | Web E2E tests | iOS E2E tests |
|---|---|---|
| Test user | `parent@test.com` / `TestPass123!` | `test@example.com` / `TestPassword1` |
| User role | parent | parent |
| Seed infrastructure | `tests/e2e/seed/seed.ts` in `recruiting-compass-web` | None yet |
| CI credential secrets | `NUXT_PUBLIC_SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` already exist |
| Service role key in CI | ✅ `SUPABASE_SERVICE_ROLE_KEY` | ❌ not yet added (needed for seeding) |

The web app's `createTestAccounts()` in `supabase-admin.ts` is the reference implementation — copy the pattern for iOS.

---

## Scope

- **Plan A (this):** ~356 Supabase-dependent E2E skips
- **Plan B (separate):** 62 UIHostingController accessibility test skips → `2026-03-19-uihostingcontroller-accessibility-tests.md`

---

## Files

**Created (iOS repo):**
- `scripts/seed-e2e.ts` — Creates iOS test user + seeds domain data (idempotent)
- `scripts/tsconfig.json` — TypeScript config for the scripts directory
- `scripts/package.json` — Node dependencies for seed script (`@supabase/supabase-js`, `tsx`)

**Modified (iOS repo):**
- `.github/workflows/ci.yml` — Add UITests step with seed + credential injection
- `.gitignore` — Add `scripts/.env.test`

**Modified (web repo):**
- `tests/e2e/config/test-accounts.ts` — Add `iosParent` account entry so web CI also provisions it

---

## Task 1: Add GitHub Actions secret for service role key

The seed script needs the Supabase service role key to create auth users (admin API). The `SUPABASE_SERVICE_ROLE_KEY` already exists as a secret in the `recruiting-compass-web` repo. Add it to the iOS repo.

- [ ] **Step 1: Add `SUPABASE_SERVICE_ROLE_KEY` to the iOS repo's GitHub secrets**

Go to: `https://github.com/<org>/recruiting-compass-ios/settings/secrets/actions`

Add a new secret:
- Name: `SUPABASE_SERVICE_ROLE_KEY`
- Value: same service role key used in `recruiting-compass-web`

This gives the iOS CI the ability to create auth users and bypass RLS for seeding.

---

## Task 2: Set up Node.js scripts infrastructure in the iOS repo

The iOS repo currently has no Node.js tooling. Add a minimal scripts directory.

**Files:**
- Create: `scripts/package.json`
- Create: `scripts/tsconfig.json`

- [ ] **Step 1: Create `scripts/package.json`**

```json
{
  "name": "recruiting-compass-ios-scripts",
  "private": true,
  "type": "module",
  "scripts": {
    "seed:e2e": "tsx seed-e2e.ts",
    "reset:e2e": "tsx reset-e2e.ts"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.49.1"
  },
  "devDependencies": {
    "tsx": "^4.19.3",
    "typescript": "^5.8.3"
  }
}
```

- [ ] **Step 2: Create `scripts/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "dist"
  },
  "include": ["*.ts"]
}
```

- [ ] **Step 3: Install dependencies**

```bash
cd scripts
npm install
```

- [ ] **Step 4: Add `.env.test` to gitignore**

```bash
echo "scripts/.env.test" >> .gitignore
echo "scripts/node_modules" >> .gitignore
echo "scripts/dist" >> .gitignore
```

- [ ] **Step 5: Create `scripts/.env.test.example`**

```bash
# Copy to scripts/.env.test and fill in your values for local dev.
# NOT committed to git. In CI, these come from GitHub Actions secrets.
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...
```

- [ ] **Step 6: Commit**

```bash
git add scripts/package.json scripts/tsconfig.json scripts/.env.test.example .gitignore
git commit -m "chore(tests): add Node.js scripts infrastructure for E2E seed"
```

---

## Task 3: Write the seed script

Mirror the web app's `createTestAccounts()` + `seed.ts` pattern for `test@example.com`.

**Files:**
- Create: `scripts/seed-e2e.ts`

- [ ] **Step 1: Check the web app's seed data to understand what columns exist**

```bash
head -100 /path/to/recruiting-compass-web/tests/e2e/seed/seed.ts
```

The web seed has schools, coaches, interactions, events, offers, performance metrics. Use the same column names.

- [ ] **Step 2: Create `scripts/seed-e2e.ts`**

```typescript
/**
 * seed-e2e.ts
 *
 * Creates the iOS E2E test user and seeds domain data.
 * Idempotent — safe to run multiple times.
 *
 * Usage:
 *   cd scripts && npm run seed:e2e
 *
 * Env vars required:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *   (SUPABASE_ANON_KEY not needed for seeding — service role bypasses RLS)
 */

import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "fs";
import { resolve } from "path";

// Load .env.test for local development
try {
  const env = readFileSync(resolve(import.meta.dirname, ".env.test"), "utf8");
  for (const line of env.split("\n")) {
    const [key, ...rest] = line.split("=");
    if (key && rest.length && !key.startsWith("#")) {
      process.env[key.trim()] = rest.join("=").trim();
    }
  }
} catch {
  // .env.test not found — rely on process.env (CI injects secrets)
}

const SUPABASE_URL = process.env.SUPABASE_URL!;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error("❌ SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const IOS_TEST_USER = {
  email: "test@example.com",
  password: "TestPassword1",
  displayName: "iOS Test Parent",
  role: "parent" as const,
};

async function getOrCreateTestUser(): Promise<string> {
  // Try to create — if already exists, look up
  const { data: createData, error: createError } =
    await supabase.auth.admin.createUser({
      email: IOS_TEST_USER.email,
      password: IOS_TEST_USER.password,
      email_confirm: true,
      user_metadata: {
        display_name: IOS_TEST_USER.displayName,
        role: IOS_TEST_USER.role,
      },
    });

  if (!createError) {
    console.log(`✅ Created test user: ${IOS_TEST_USER.email}`);
    return createData.user.id;
  }

  if (
    createError.message.includes("already been registered") ||
    createError.message.includes("already registered")
  ) {
    const { data: listData } = await supabase.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    const existing = listData?.users?.find((u) => u.email === IOS_TEST_USER.email);
    if (!existing) throw new Error(`Could not find existing user: ${IOS_TEST_USER.email}`);
    console.log(`⏭️  Test user already exists: ${IOS_TEST_USER.email}`);
    return existing.id;
  }

  throw createError;
}

async function ensureOnboardingComplete(userId: string) {
  await supabase
    .from("users")
    .update({
      role: IOS_TEST_USER.role,
      onboarding_completed: true,
      phase_milestone_data: {
        onboarding_complete: true,
        onboarding_completed_at: new Date().toISOString(),
      },
    })
    .eq("id", userId);
}

async function getOrCreateFamilyUnit(userId: string): Promise<string> {
  const { data: existing } = await supabase
    .from("family_members")
    .select("family_unit_id")
    .eq("user_id", userId)
    .maybeSingle();

  if (existing) return existing.family_unit_id;

  const { data: family, error } = await supabase
    .from("family_units")
    .insert({ family_name: "iOS Test Family", created_by_user_id: userId })
    .select()
    .single();

  if (error) throw error;

  await supabase.from("family_members").insert({
    family_unit_id: family.id,
    user_id: userId,
    role: "parent",
  });

  console.log(`✅ Created family unit: ${family.id}`);
  return family.id;
}

async function seedSchools(familyUnitId: string): Promise<string[]> {
  const schools = [
    {
      family_unit_id: familyUnitId,
      name: "Duke University",
      division: "D1",
      conference: "ACC",
      location: "Durham, NC",
      state: "NC",
      city: "Durham",
      recruiting_status: "interested",
    },
    {
      family_unit_id: familyUnitId,
      name: "Duke University", // duplicate name — triggers duplicate detection test
      division: "D1",
      conference: "ACC",
      location: "Durham, NC",
      state: "NC",
      city: "Durham",
      recruiting_status: "considering",
    },
  ];

  const { data, error } = await supabase
    .from("schools")
    .upsert(schools, { onConflict: "family_unit_id,name", ignoreDuplicates: false })
    .select("id");

  if (error) { console.warn("⚠️  Schools:", error.message); return []; }
  console.log(`✅ Schools: ${data.length}`);
  return data.map((s) => s.id);
}

async function seedCoaches(familyUnitId: string, schoolId: string): Promise<string[]> {
  const coaches = [
    {
      family_unit_id: familyUnitId,
      school_id: schoolId,
      first_name: "John",
      last_name: "Smith",
      title: "Head Coach",
      email: "jsmith@duke.edu",
    },
    {
      family_unit_id: familyUnitId,
      school_id: schoolId,
      first_name: "Jane",
      last_name: "Doe",
      title: "Assistant Coach",
      email: "jdoe@duke.edu",
    },
  ];

  const { data, error } = await supabase
    .from("coaches")
    .upsert(coaches, { onConflict: "family_unit_id,email", ignoreDuplicates: false })
    .select("id");

  if (error) { console.warn("⚠️  Coaches:", error.message); return []; }
  console.log(`✅ Coaches: ${data.length}`);
  return data.map((c) => c.id);
}

async function seedInteractions(
  familyUnitId: string, userId: string, schoolId: string, coachId: string
) {
  const { error } = await supabase.from("interactions").upsert([
    {
      family_unit_id: familyUnitId,
      school_id: schoolId,
      coach_id: coachId,
      user_id: userId,
      type: "email",
      direction: "inbound",
      sentiment: "positive",
      subject: "Campus Visit Invitation",
      content: "Coach Smith invited us to an official campus visit.",
      occurred_at: new Date(Date.now() - 3 * 86400000).toISOString(),
    },
  ], { onConflict: "family_unit_id,school_id,occurred_at", ignoreDuplicates: true });
  if (error) console.warn("⚠️  Interactions:", error.message);
  else console.log("✅ Interactions seeded");
}

async function seedEvents(familyUnitId: string) {
  const { error } = await supabase.from("events").upsert([
    {
      family_unit_id: familyUnitId,
      title: "Spring Showcase",
      event_type: "showcase",
      start_date: new Date(Date.now() + 7 * 86400000).toISOString(),
      end_date: new Date(Date.now() + 7 * 86400000 + 4 * 3600000).toISOString(),
      location: "Durham, NC",
    },
  ], { onConflict: "family_unit_id,title,start_date", ignoreDuplicates: true });
  if (error) console.warn("⚠️  Events:", error.message);
  else console.log("✅ Events seeded");
}

async function seedOffers(familyUnitId: string, schoolId: string, coachId: string) {
  const { error } = await supabase.from("offers").upsert([
    {
      family_unit_id: familyUnitId,
      school_id: schoolId,
      coach_id: coachId,
      scholarship_type: "athletic",
      scholarship_percentage: 100,
      annual_value: 55000,
      offer_date: new Date(Date.now() - 30 * 86400000).toISOString(),
      expiration_date: new Date(Date.now() + 60 * 86400000).toISOString(),
      status: "active",
      notes: "Full athletic scholarship offer.",
    },
    {
      family_unit_id: familyUnitId,
      school_id: schoolId,
      coach_id: null,
      scholarship_type: "athletic",
      scholarship_percentage: 75,
      annual_value: 41250,
      offer_date: new Date(Date.now() - 15 * 86400000).toISOString(),
      expiration_date: new Date(Date.now() + 45 * 86400000).toISOString(),
      status: "active",
      notes: "75% scholarship offer.",
    },
  ], { onConflict: "family_unit_id,school_id,offer_date", ignoreDuplicates: true });
  if (error) console.warn("⚠️  Offers:", error.message);
  else console.log("✅ Offers seeded");
}

async function seedPerformanceMetrics(userId: string) {
  const { error } = await supabase.from("performance_metrics").upsert([
    {
      user_id: userId,
      metric_type: "velocity",
      value: 87.5,
      unit: "mph",
      recorded_date: new Date(Date.now() - 7 * 86400000).toISOString(),
      verified: true,
      notes: "Peak velocity.",
    },
    {
      user_id: userId,
      metric_type: "velocity",
      value: 85.0,
      unit: "mph",
      recorded_date: new Date(Date.now() - 14 * 86400000).toISOString(),
      verified: false,
    },
    {
      user_id: userId,
      metric_type: "exit_velocity",
      value: 95.2,
      unit: "mph",
      recorded_date: new Date(Date.now() - 10 * 86400000).toISOString(),
      verified: true,
    },
  ], { onConflict: "user_id,metric_type,recorded_date", ignoreDuplicates: true });
  if (error) console.warn("⚠️  Performance metrics:", error.message);
  else console.log("✅ Performance metrics seeded");
}

async function seedNotifications(userId: string) {
  // Notifications don't have a good upsert key — check count first
  const { count } = await supabase
    .from("notifications")
    .select("*", { count: "exact", head: true })
    .eq("user_id", userId);

  if ((count ?? 0) >= 2) {
    console.log("⏭️  Notifications already seeded");
    return;
  }

  const { error } = await supabase.from("notifications").insert([
    {
      user_id: userId,
      title: "New offer from Duke University",
      body: "Coach Smith sent you an offer. Tap to review.",
      notification_type: "offer",
      is_read: false,
    },
    {
      user_id: userId,
      title: "Interaction logged",
      body: "Your recent email with Coach Smith has been logged.",
      notification_type: "interaction",
      is_read: true,
    },
  ]);
  if (error) console.warn("⚠️  Notifications:", error.message);
  else console.log("✅ Notifications seeded");
}

async function seedDocuments(familyUnitId: string, userId: string, schoolId: string) {
  const { error } = await supabase.from("documents").upsert([
    {
      family_unit_id: familyUnitId,
      school_id: schoolId,
      user_id: userId,
      title: "Transcript 2026",
      document_type: "transcript",
      file_url: "https://example.com/placeholder-transcript.pdf",
    },
  ], { onConflict: "family_unit_id,title", ignoreDuplicates: true });
  if (error) console.warn("⚠️  Documents:", error.message);
  else console.log("✅ Documents seeded");
}

async function main() {
  console.log("🌱 iOS E2E Seed starting...");

  const userId = await getOrCreateTestUser();
  await ensureOnboardingComplete(userId);
  const familyUnitId = await getOrCreateFamilyUnit(userId);

  const schoolIds = await seedSchools(familyUnitId);
  const primarySchoolId = schoolIds[0];

  if (!primarySchoolId) {
    console.warn("⚠️  No school created — skipping coach/interaction/offer seeds");
  } else {
    const coachIds = await seedCoaches(familyUnitId, primarySchoolId);
    const primaryCoachId = coachIds[0];

    if (primaryCoachId) {
      await seedInteractions(familyUnitId, userId, primarySchoolId, primaryCoachId);
      await seedOffers(familyUnitId, primarySchoolId, primaryCoachId);
    }
    await seedDocuments(familyUnitId, userId, primarySchoolId);
  }

  await seedEvents(familyUnitId);
  await seedPerformanceMetrics(userId);
  await seedNotifications(userId);

  console.log("\n✅ iOS E2E seed complete!");
  console.log(`   User: ${IOS_TEST_USER.email}`);
  console.log(`   Family: ${familyUnitId}`);
}

main().catch((err) => {
  console.error("❌ Seed failed:", err);
  process.exit(1);
});
```

- [ ] **Step 3: Verify the seed runs locally**

First, create `scripts/.env.test` with real credentials (never commit this):
```bash
cp scripts/.env.test.example scripts/.env.test
# Fill in SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
```

Then run:
```bash
cd scripts && npm run seed:e2e
```

Expected output:
```
🌱 iOS E2E Seed starting...
✅ Created test user: test@example.com  (or "already exists")
✅ Schools: 2
✅ Coaches: 2
✅ Interactions seeded
✅ Offers seeded
...
✅ iOS E2E seed complete!
```

If any step fails with a column mismatch, check the actual schema:
```bash
# In Supabase SQL Editor
SELECT column_name FROM information_schema.columns WHERE table_name = 'schools';
```

Fix column names in the seed script to match.

- [ ] **Step 4: Commit the seed script**

```bash
git add scripts/seed-e2e.ts
git commit -m "chore(tests): add iOS E2E test seed script

Creates test@example.com parent user with family, schools, coaches,
interactions, events, offers, performance metrics, notifications,
and documents. Mirrors the web app's createTestAccounts() pattern."
```

---

## Task 4: Configure local Xcode scheme

For local development, the test scheme needs `SUPABASE_URL` and `SUPABASE_ANON_KEY` so UITests can connect.

- [ ] **Step 1: Open scheme editor in Xcode**

`Product` → `Scheme` → `Edit Scheme` → `Test` tab → `Arguments` tab

- [ ] **Step 2: Add environment variables under "Environment Variables"**

| Name | Value |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Your anon key |

- [ ] **Step 3: Ensure scheme is NOT shared (stays local)**

Uncheck "Shared" in the scheme editor. Local schemes are gitignored automatically.

- [ ] **Step 4: Verify a quick smoke test works**

```bash
cd TheRecruitingCompass
xcodebuild test \
  -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/AddCoachE2ETests/testAddCoach_withoutFirstName_showsValidationError \
  2>&1 | grep -E "passed|failed|skipped"
```

Expected: `passed` (not skipped).

---

## Task 5: Add UITests step to iOS CI

The existing `ci.yml` already has `SUPABASE_URL` and `SUPABASE_ANON_KEY` as secrets. Add:
1. A seed step (using the new Node.js script)
2. A UITests step

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read the current ci.yml**

Note the existing `build-and-test` job structure. We'll add a new parallel `e2e-tests` job so unit tests and E2E tests run in parallel (faster CI).

- [ ] **Step 2: Add the `e2e-tests` job to `.github/workflows/ci.yml`**

```yaml
  e2e-tests:
    name: E2E UITests
    runs-on: macos-latest
    # Only run on PRs to main and manual triggers (E2E is slow)
    if: github.event_name == 'pull_request' || github.event_name == 'workflow_dispatch'
    env:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
      SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
      SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app

      - name: Boot simulator
        run: |
          UDID=$(xcrun simctl list devices available | grep 'iPhone 16' | grep -v 'Plus\|Pro' | head -1 | grep -oE '[0-9A-F-]{36}')
          echo "SIMULATOR_UDID=$UDID" >> $GITHUB_ENV
          xcrun simctl boot "$UDID" || true

      - name: Create Release.xcconfig
        run: |
          _SLASH = /
          cat > TheRecruitingCompass/Release.xcconfig << 'XCCONFIG'
          _SLASH = /
          SUPABASE_URL = https:$(_SLASH)$(_SLASH)ci-placeholder.supabase.co
          SUPABASE_ANON_KEY = ci_placeholder_key
          API_BASE_URL = https:$(_SLASH)$(_SLASH)myrecruitingcompass.com
          XCCONFIG

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install seed script dependencies
        run: cd scripts && npm ci

      - name: Seed E2E test data
        run: cd scripts && npm run seed:e2e
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}

      - name: Cache DerivedData
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: deriveddata-e2e-${{ hashFiles('TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj') }}
          restore-keys: deriveddata-e2e-

      - name: Build for testing
        run: |
          cd TheRecruitingCompass
          xcodebuild build-for-testing \
            -scheme TheRecruitingCompass \
            -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
            -quiet

      - name: Run UITests
        run: |
          cd TheRecruitingCompass
          xcodebuild test-without-building \
            -scheme TheRecruitingCompass \
            -destination 'platform=iOS Simulator,OS=latest,name=iPhone 16' \
            -only-testing:TheRecruitingCompassUITests \
            -test-iterations 1 \
            -quiet \
            SUPABASE_URL="${{ env.SUPABASE_URL }}" \
            SUPABASE_ANON_KEY="${{ env.SUPABASE_ANON_KEY }}"

      - name: Upload xcresult
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: xcresult-e2e
          path: ~/Library/Developer/Xcode/DerivedData/**/Logs/Test/*.xcresult
          retention-days: 7
```

Note: `xcodebuild test-without-building ... SUPABASE_URL="..." SUPABASE_ANON_KEY="..."` passes the env vars as build settings that become available via `ProcessInfo.processInfo.environment` in the test runner.

- [ ] **Step 3: Commit the CI update**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add E2E UITests job with Supabase seed

Adds a parallel e2e-tests job that:
1. Seeds test@example.com user + domain data via scripts/seed-e2e.ts
2. Runs the full TheRecruitingCompassUITests bundle
3. Uploads xcresult artifact for inspection

Runs only on PRs to main and workflow_dispatch (not on every push)."
```

---

## Task 6: Verify end-to-end

- [ ] **Step 1: Open a draft PR to trigger the new CI job**

```bash
git checkout -b test/e2e-ci-verification
git push origin test/e2e-ci-verification
# Open a draft PR in GitHub
```

The new `E2E UITests` job should appear alongside the existing `Build & Unit Tests` job.

- [ ] **Step 2: Monitor the CI run**

Watch the `Run UITests` step output. Expected progress:
- `Login failed` skips → `passed` ✅
- `Content did not load` skips → `passed` (if seed covered that feature)

- [ ] **Step 3: Check the failure/skip count**

Download the xcresult artifact and run:
```bash
xcrun xcresulttool get object --legacy --path <path>.xcresult --format json 2>/dev/null | \
  python3 -c "
import json,sys
data=json.load(sys.stdin)
def counts(o, p=0, f=0, s=0):
    if isinstance(o,dict):
        t=o.get('testStatus',{}).get('_value','')
        if t=='Success': p+=1
        elif t=='Failure': f+=1
        elif t=='Skipped': s+=1
        for v in o.values(): p,f,s=counts(v,p,f,s)
    elif isinstance(o,list):
        for i in o: p,f,s=counts(i,p,f,s)
    return p,f,s
p,f,s=counts(data)
print(f'Passed: {p}, Failed: {f}, Skipped: {s}')
"
```

**Target:** 0 failures, skips ≤62.

- [ ] **Step 4: Fix any remaining seed gaps**

For any test still skipping with data-related messages (not UIHostingController), add the missing data to `scripts/seed-e2e.ts` and re-run.

- [ ] **Step 5: Merge and close draft PR**

---

## Task 7: Add `test@example.com` to web app's test accounts (cross-repo)

This ensures the web app's CI also provisions the iOS test user. If the web CI runs before iOS CI (e.g., on a shared PR), the user already exists.

**Files (in `recruiting-compass-web`):**
- Modify: `tests/e2e/config/test-accounts.ts`

- [ ] **Step 1: Add iOS parent account to `TEST_ACCOUNTS`**

```typescript
export const TEST_ACCOUNTS = {
  player: { email: "player@test.com", password: "TestPass123!", ... },
  parent: { email: "parent@test.com", password: "TestPass123!", ... },
  admin:  { email: "admin@test.com",  password: "TestPass123!", ... },
  // iOS E2E test account — provisioned by web CI so it exists when iOS CI runs
  iosParent: {
    email: "test@example.com",
    password: "TestPassword1",
    displayName: "iOS Test Parent",
    role: "parent" as const,
  },
} as const;
```

The web app's `createTestAccounts()` will now also create this user on every web CI run, ensuring the iOS test user exists even before the iOS seed script runs.

- [ ] **Step 2: Commit in web repo**

```bash
cd /path/to/recruiting-compass-web
git add tests/e2e/config/test-accounts.ts
git commit -m "chore(tests): provision iOS test user (test@example.com) via web CI"
```

---

## Unresolved Questions

1. **Does `xcodebuild ... SUPABASE_URL="..."` correctly inject the value into `ProcessInfo.processInfo.environment`?** The xcodebuild build setting injection might need `-testenv SUPABASE_URL="..."` instead. Check the actual flag syntax in your Xcode version:
   ```bash
   xcodebuild test --help | grep -A2 "testenv"
   ```
   If `-testenv` is supported, prefer it over build settings.

2. **What are the exact column names for `schools.recruiting_status` vs `status`, `coaches.title` vs `role`, `offers.scholarship_type`, etc.?** Run column checks against the real Supabase schema before the seed script will work. See Task 3 Step 3.

3. **Does the E2E job need a separate GitHub Actions runner with longer timeout?** The full UITest suite (59 test classes) could take 30-60 minutes. Consider adding `timeout-minutes: 60` to the e2e-tests job.

4. **Should E2E tests run on every push to main, or only on PRs?** Currently scoped to PRs + workflow_dispatch. Adjust the `if:` condition in the job definition if needed.
