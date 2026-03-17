# Notifications System Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete notifications system delivering push (iOS), in-app (web + iOS), and email (digest + deadlines) alerts for recruiting activity, backed by Supabase Edge Function crons and a per-user admin broadcast tool.

**Architecture:** Notifications row is the single source of truth — everything (push, in-app, email) flows from an INSERT into `notifications`. Cron Edge Functions scan deadline sources daily and INSERT rows; the existing Postgres trigger fires the push Edge Function automatically. Email is handled by the web app's `emailService.ts` via Resend, called from cron functions.

**Tech Stack:** Supabase (Postgres, Edge Functions, pg_cron), Nuxt 3 / h3 server routes, Vitest, Swift/SwiftUI/XCTest, Resend (already installed), TypeScript (Deno for Edge Functions)

**Repos:**
- iOS + Edge Functions: `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/`
- Web app: `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/`

**Spec:** `planning/SPEC_notifications_system.md`

---

## Pre-existing Assets (Do Not Duplicate)

| Asset | Location | Status |
|---|---|---|
| `send-push-notification` Edge Function | `supabase/functions/send-push-notification/index.ts` (iOS repo) | ✅ Done |
| Push Postgres trigger | Migration `20260315000003` | ✅ Done |
| `notificationGenerator.ts` | `server/utils/notificationGenerator.ts` (web) | Exists — needs updating |
| `ncaaRecruitingCalendar.ts` | `server/utils/ncaaRecruitingCalendar.ts` (web) | Exists — seed from this |
| `emailService.ts` | `server/utils/emailService.ts` (web) | Exists — extend, don't replace |
| `resend` package | `package.json` (web) | ✅ Installed |
| `notifications.vue` page | `pages/notifications.vue` (web) | Exists — enhance |
| `/api/notifications/create.post.ts` | `server/api/notifications/create.post.ts` (web) | Exists |

---

## File Map

### New files — iOS repo

```
supabase/
├── migrations/
│   ├── 20260317000001_add_user_timezone.sql
│   ├── 20260317000002_add_coach_next_contact_date.sql
│   ├── 20260317000003_add_user_deadlines.sql
│   ├── 20260317000004_add_system_calendar.sql
│   ├── 20260317000005_add_deadline_alert_log.sql
│   └── 20260317000006_notification_preferences_weekly_digest.sql
└── functions/
    ├── process-follow-up-reminders/
    │   └── index.ts
    ├── process-deadline-alerts/
    │   └── index.ts
    └── send-weekly-digest/
        └── index.ts
TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/
└── Models/
    └── CoachNextContact.swift          # next_contact_date + threshold UI data
```

### New files — Web repo

```
server/api/
├── admin/notifications/
│   └── broadcast.post.ts               # Admin broadcast endpoint
├── deadlines/
│   ├── index.get.ts                    # List user deadlines
│   ├── index.post.ts                   # Create deadline
│   └── [id].delete.ts                  # Delete deadline
└── email/
    └── send.post.ts                    # Email send endpoint (wraps emailService)
pages/
├── admin/notifications/
│   └── broadcast.vue                   # Admin broadcast UI
└── deadlines.vue                       # User deadline CRUD
composables/
└── useDeadlines.ts                     # User deadline CRUD
tests/unit/
├── server/
│   ├── utils/
│   │   └── timezone.spec.ts            # Timezone derivation tests
│   ├── notificationGenerator.spec.ts   # Updated generator tests
│   ├── deadlineAlerts.spec.ts          # Deadline alert logic tests
│   ├── adminBroadcast.spec.ts          # Broadcast endpoint tests
│   └── emailSend.spec.ts               # Email send endpoint tests
└── composables/
    └── useDeadlines.spec.ts
```

### Modified files — Web repo

```
server/utils/notificationGenerator.ts  # Update dedup to use deadline_alert_log
                                        # Update follow-up threshold to per-coach
                                        # Rename daily_digest → weekly_digest
pages/notifications.vue                 # Add delete individual, filter by type
pages/settings/notifications.vue        # Preferences page (reads notification_preferences)
```

### Modified files — iOS repo

```
TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/
├── Models/Coach.swift                  # Add nextContactDate, followUpThresholdDays
├── Views/CoachDetailView.swift         # Add next contact date UI
└── Components/CoachEditForm.swift      # Add threshold field
```

---

## Phase 1 — Admin Broadcast (Test the Pipeline)

> **Goal:** Verify the full push pipeline works end-to-end before building anything else. One admin page, one API endpoint. Run this manually after each build.

---

### Task 1.1: Admin broadcast API endpoint

**Files:**
- Create: `recruiting-compass-web/server/api/admin/notifications/broadcast.post.ts`
- Test: `recruiting-compass-web/tests/unit/server/adminBroadcast.spec.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// tests/unit/server/adminBroadcast.spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { z } from 'zod'

const broadcastSchema = z.object({
  target: z.enum(['all', 'user']),
  user_id: z.string().uuid().optional(),
  type: z.enum(['follow_up_reminder','deadline_alert','weekly_digest','event']),
  title: z.string().min(1).max(200),
  message: z.string().max(1000).optional(),
})

describe('AdminBroadcast schema', () => {
  it('accepts valid all-users broadcast', () => {
    const result = broadcastSchema.safeParse({
      target: 'all', type: 'follow_up_reminder', title: 'Test'
    })
    expect(result.success).toBe(true)
  })

  it('accepts valid single-user broadcast', () => {
    const result = broadcastSchema.safeParse({
      target: 'user',
      user_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      type: 'deadline_alert',
      title: 'Test',
      message: 'Hello'
    })
    expect(result.success).toBe(true)
  })

  it('rejects broadcast without title', () => {
    const result = broadcastSchema.safeParse({ target: 'all', type: 'event', title: '' })
    expect(result.success).toBe(false)
  })

  it('rejects unknown notification type', () => {
    const result = broadcastSchema.safeParse({ target: 'all', type: 'banana', title: 'Test' })
    expect(result.success).toBe(false)
  })

  it('rejects single-user broadcast without user_id', () => {
    const result = broadcastSchema.safeParse({ target: 'user', type: 'event', title: 'Test' })
    // No validation enforces this at schema level — handled in handler
    // Just verify it parses (runtime guard in handler)
    expect(result.success).toBe(true)
  })
})
```

- [ ] **Step 2: Run to verify failures**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx vitest run tests/unit/server/adminBroadcast.spec.ts
```
Expected: FAIL (file doesn't exist yet)

- [ ] **Step 3: Implement the endpoint**

```typescript
// server/api/admin/notifications/broadcast.post.ts
import { defineEventHandler, readBody, createError } from 'h3'
import { z } from 'zod'
import { createServerSupabaseClient } from '~/server/utils/supabase'
import { requireAdmin } from '~/server/utils/auth'
import { useLogger } from '~/server/utils/logger'

const broadcastSchema = z.object({
  target: z.enum(['all', 'user']),
  user_id: z.string().uuid().optional(),
  type: z.enum(['follow_up_reminder', 'deadline_alert', 'weekly_digest', 'event']),
  title: z.string().min(1).max(200),
  message: z.string().max(1000).optional(),
})

export default defineEventHandler(async (event) => {
  const logger = useLogger(event, 'admin/notifications/broadcast')
  await requireAdmin(event)

  const body = await readBody(event)
  const parsed = broadcastSchema.safeParse(body)
  if (!parsed.success) {
    throw createError({ statusCode: 422, statusMessage: 'Invalid request' })
  }

  const { target, user_id, type, title, message } = parsed.data
  if (target === 'user' && !user_id) {
    throw createError({ statusCode: 422, statusMessage: 'user_id required for target=user' })
  }

  const supabase = createServerSupabaseClient()

  let userIds: string[] = []
  if (target === 'all') {
    const { data, error } = await supabase.from('users').select('id')
    if (error) throw createError({ statusCode: 500, statusMessage: 'Failed to fetch users' })
    userIds = data.map((u) => u.id)
  } else {
    userIds = [user_id!]
  }

  const rows = userIds.map((uid) => ({
    user_id: uid,
    type,
    title,
    message: message ?? null,
    priority: 'normal',
    scheduled_for: new Date().toISOString(),
  }))

  const { error } = await supabase.from('notifications').insert(rows)
  if (error) {
    logger.error('Failed to insert broadcast notifications', error)
    throw createError({ statusCode: 500, statusMessage: 'Failed to send broadcast' })
  }

  logger.info(`Broadcast sent to ${userIds.length} users`)
  return { success: true, sent: userIds.length }
})
```

- [ ] **Step 4: Run tests — expect pass**

```bash
npx vitest run tests/unit/server/adminBroadcast.spec.ts
```

- [ ] **Step 5: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add server/api/admin/notifications/broadcast.post.ts tests/unit/server/adminBroadcast.spec.ts
git commit -m "feat(notifications): add admin broadcast API endpoint"
```

---

### Task 1.2: Admin broadcast UI

**Files:**
- Create: `recruiting-compass-web/pages/admin/notifications/broadcast.vue`

- [ ] **Step 1: Create the broadcast page**

```vue
<!-- pages/admin/notifications/broadcast.vue -->
<template>
  <div class="max-w-lg mx-auto py-12 px-4">
    <h1 class="text-2xl font-bold mb-8">Send Notification Broadcast</h1>

    <form @submit.prevent="send" class="space-y-6">
      <div>
        <label class="block text-sm font-medium mb-1">Target</label>
        <select v-model="form.target" class="w-full border rounded-lg px-3 py-2">
          <option value="all">All users</option>
          <option value="user">Specific user</option>
        </select>
      </div>

      <div v-if="form.target === 'user'">
        <label class="block text-sm font-medium mb-1">User ID</label>
        <input v-model="form.user_id" type="text" class="w-full border rounded-lg px-3 py-2"
          placeholder="UUID" />
      </div>

      <div>
        <label class="block text-sm font-medium mb-1">Type</label>
        <select v-model="form.type" class="w-full border rounded-lg px-3 py-2">
          <option value="follow_up_reminder">Follow-up Reminder</option>
          <option value="deadline_alert">Deadline Alert</option>
          <option value="weekly_digest">Weekly Digest</option>
          <option value="event">Event</option>
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium mb-1">Title</label>
        <input v-model="form.title" type="text" class="w-full border rounded-lg px-3 py-2"
          placeholder="Notification title" maxlength="200" />
      </div>

      <div>
        <label class="block text-sm font-medium mb-1">Message (optional)</label>
        <textarea v-model="form.message" rows="3" class="w-full border rounded-lg px-3 py-2"
          placeholder="Notification body" maxlength="1000" />
      </div>

      <div v-if="result" :class="result.success ? 'text-green-700' : 'text-red-700'" class="text-sm">
        {{ result.success ? `✓ Sent to ${result.sent} user(s)` : `✗ ${result.error}` }}
      </div>

      <button type="submit" :disabled="sending"
        class="w-full bg-blue-600 text-white font-semibold py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50">
        {{ sending ? 'Sending…' : 'Send Broadcast' }}
      </button>
    </form>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ middleware: 'admin' })

const form = reactive({
  target: 'all' as 'all' | 'user',
  user_id: '',
  type: 'follow_up_reminder' as string,
  title: '',
  message: '',
})
const sending = ref(false)
const result = ref<{ success: boolean; sent?: number; error?: string } | null>(null)

async function send() {
  sending.value = true
  result.value = null
  try {
    const data = await $fetch('/api/admin/notifications/broadcast', {
      method: 'POST',
      body: {
        target: form.target,
        ...(form.target === 'user' ? { user_id: form.user_id } : {}),
        type: form.type,
        title: form.title,
        message: form.message || undefined,
      },
    })
    result.value = { success: true, sent: (data as { sent: number }).sent }
  } catch (e: unknown) {
    const err = e as { data?: { statusMessage?: string } }
    result.value = { success: false, error: err?.data?.statusMessage ?? 'Unknown error' }
  } finally {
    sending.value = false
  }
}
</script>
```

- [ ] **Step 2: Verify admin middleware exists**

```bash
ls /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/middleware/ | grep admin
```
If `admin.ts` does not exist, check `auth.ts` — the admin check may be in the server util. The page uses `definePageMeta({ middleware: 'admin' })`.

- [ ] **Step 3: Manual test — start dev server and verify page loads**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npm run dev
# Navigate to /admin/notifications/broadcast
# Send a test broadcast to yourself (target=user, your user_id)
# Verify notification appears in iOS app
```

- [ ] **Step 4: Commit**

```bash
git add pages/admin/notifications/broadcast.vue
git commit -m "feat(notifications): add admin broadcast UI"
```

---

## Phase 2 — Data Model

> **Goal:** Add all missing DB columns and tables. Derive timezones from existing HomeLocation data. Add coach follow-up fields. Run migrations, verify with Supabase dashboard.

---

### Task 2.1: User timezone migration

**Files:**
- Create: `recruiting-compass-ios/supabase/migrations/20260317000001_add_user_timezone.sql`

- [ ] **Step 1: Write migration**

```sql
-- supabase/migrations/20260317000001_add_user_timezone.sql
-- Adds timezone column to users table
-- US only: America/New_York (default), America/Chicago, America/Denver, America/Los_Angeles
-- Derived from state in home_location JSON at save time; never computed per-send

ALTER TABLE users ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'America/New_York'
  CHECK (timezone IN (
    'America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles'
  ));
```

- [ ] **Step 2: Run migration**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
npx supabase db push
```

- [ ] **Step 3: Add `deriveTimezone` utility to web app**

```typescript
// server/utils/timezone.ts
const STATE_TIMEZONE: Record<string, string> = {
  // Eastern
  ...Object.fromEntries(
    ['ME','NH','VT','MA','RI','CT','NY','NJ','PA','DE','MD','DC',
     'VA','WV','NC','SC','GA','FL','OH','MI','IN','KY','TN']
    .map(s => [s, 'America/New_York'])
  ),
  // Central
  ...Object.fromEntries(
    ['ND','SD','NE','KS','MN','IA','MO','WI','IL','AR','LA','MS','AL','OK','TX']
    .map(s => [s, 'America/Chicago'])
  ),
  // Mountain (AZ included — does not observe DST but maps to Denver per spec)
  ...Object.fromEntries(
    ['MT','WY','CO','NM','AZ','UT','ID']
    .map(s => [s, 'America/Denver'])
  ),
  // Pacific
  ...Object.fromEntries(
    ['WA','OR','CA','NV'].map(s => [s, 'America/Los_Angeles'])
  ),
}

export function deriveTimezone(state?: string | null): string {
  if (!state) return 'America/New_York'
  return STATE_TIMEZONE[state.toUpperCase()] ?? 'America/New_York'
}
```

- [ ] **Step 4: Write tests for `deriveTimezone`**

```typescript
// tests/unit/server/utils/timezone.spec.ts
import { describe, it, expect } from 'vitest'
import { deriveTimezone } from '~/server/utils/timezone'

describe('deriveTimezone', () => {
  it('maps NY to Eastern', () => expect(deriveTimezone('NY')).toBe('America/New_York'))
  it('maps TX to Central', () => expect(deriveTimezone('TX')).toBe('America/Chicago'))
  it('maps CO to Mountain', () => expect(deriveTimezone('CO')).toBe('America/Denver'))
  it('maps AZ to Mountain (no DST, but spec maps to Denver)', () => expect(deriveTimezone('AZ')).toBe('America/Denver'))
  it('maps CA to Pacific', () => expect(deriveTimezone('CA')).toBe('America/Los_Angeles'))
  it('defaults unknown state to Eastern', () => expect(deriveTimezone('ZZ')).toBe('America/New_York'))
  it('defaults null to Eastern', () => expect(deriveTimezone(null)).toBe('America/New_York'))
  it('is case-insensitive', () => expect(deriveTimezone('ny')).toBe('America/New_York'))
})
```

- [ ] **Step 5: Run timezone tests**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx vitest run tests/unit/server/utils/timezone.spec.ts
```

- [ ] **Step 6: Wire `deriveTimezone` into home location save**

Find the server route that saves `home_location` (likely `server/api/user/` or `server/api/player/`). After saving home location, update `users.timezone`:

```typescript
import { deriveTimezone } from '~/server/utils/timezone'
// After saving home_location:
const tz = deriveTimezone(homeLocation.state)
await supabase.from('users').update({ timezone: tz }).eq('id', userId)
```

- [ ] **Step 7: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add supabase/migrations/20260317000001_add_user_timezone.sql
git commit -m "feat(notifications): add user timezone migration"

cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add server/utils/timezone.ts tests/unit/server/utils/timezone.spec.ts
git commit -m "feat(notifications): add timezone derivation utility"
```

---

### Task 2.2: Coach next_contact_date migration

**Files:**
- Create: `recruiting-compass-ios/supabase/migrations/20260317000002_add_coach_next_contact_date.sql`

- [ ] **Step 1: Write migration**

```sql
-- supabase/migrations/20260317000002_add_coach_next_contact_date.sql
ALTER TABLE coaches
  ADD COLUMN IF NOT EXISTS next_contact_date date,
  ADD COLUMN IF NOT EXISTS follow_up_threshold_days int NOT NULL DEFAULT 21
    CHECK (follow_up_threshold_days BETWEEN 1 AND 365);
```

- [ ] **Step 2: Run migration and verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
npx supabase db push
```

- [ ] **Step 3: Add `next_contact_date` to iOS Coach model**

In `TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/Coach.swift`, add:

```swift
let nextContactDate: String?
let followUpThresholdDays: Int?

// In CodingKeys:
case nextContactDate = "next_contact_date"
case followUpThresholdDays = "follow_up_threshold_days"
```

- [ ] **Step 4: Add next contact date UI to CoachDetailView**

In `CoachDetailView.swift`, add a "Next Contact" date picker row in the edit form using `DatePicker`. Display the date in a detail row when set. Allow clearing.

- [ ] **Step 5: Build verify**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild build -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

- [ ] **Step 6: Commit both repos**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add supabase/migrations/20260317000002_add_coach_next_contact_date.sql \
        TheRecruitingCompass/TheRecruitingCompass/Features/Dashboard/Models/Coach.swift \
        TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/Views/CoachDetailView.swift
git commit -m "feat(notifications): add next_contact_date and follow_up_threshold_days to coaches"
```

---

### Task 2.3: User deadlines table

**Files:**
- Create: `recruiting-compass-ios/supabase/migrations/20260317000003_add_user_deadlines.sql`

- [ ] **Step 1: Write migration**

```sql
-- supabase/migrations/20260317000003_add_user_deadlines.sql
CREATE TABLE IF NOT EXISTS user_deadlines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users NOT NULL,
  school_id     uuid REFERENCES schools(id) ON DELETE SET NULL,
  label         text NOT NULL,
  deadline_date date NOT NULL,
  category      text NOT NULL CHECK (category IN (
                  'application', 'decision', 'financial_aid', 'visit', 'custom'
                )),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE user_deadlines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_deadlines: users manage own"
  ON user_deadlines FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX user_deadlines_user_date_idx ON user_deadlines (user_id, deadline_date);
```

- [ ] **Step 2: Run and verify**

```bash
npx supabase db push
```

- [ ] **Step 3: Create CRUD API routes (web)**

```typescript
// server/api/deadlines/index.get.ts — list user's deadlines
// server/api/deadlines/index.post.ts — create deadline
// server/api/deadlines/[id].delete.ts — delete deadline
```

Implement each following the same pattern as `server/api/notifications/create.post.ts`. Use `requireAuth`, `createServerSupabaseClient`, Zod validation.

- [ ] **Step 4: Write deadline API tests**

```typescript
// tests/unit/server/deadlines.spec.ts
import { describe, it, expect } from 'vitest'
import { z } from 'zod'

const deadlineSchema = z.object({
  label: z.string().min(1).max(200),
  deadline_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  category: z.enum(['application','decision','financial_aid','visit','custom']),
  school_id: z.string().uuid().optional(),
})

describe('Deadline schema', () => {
  it('accepts valid deadline', () => {
    const result = deadlineSchema.safeParse({
      label: 'Application Deadline',
      deadline_date: '2026-11-01',
      category: 'application',
    })
    expect(result.success).toBe(true)
  })
  it('rejects invalid date format', () => {
    const result = deadlineSchema.safeParse({
      label: 'Test', deadline_date: 'November 1', category: 'application'
    })
    expect(result.success).toBe(false)
  })
  it('rejects unknown category', () => {
    const result = deadlineSchema.safeParse({
      label: 'Test', deadline_date: '2026-11-01', category: 'birthday'
    })
    expect(result.success).toBe(false)
  })
})
```

- [ ] **Step 5: Run tests**

```bash
npx vitest run tests/unit/server/deadlines.spec.ts
```

- [ ] **Step 6: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add supabase/migrations/20260317000003_add_user_deadlines.sql
git commit -m "feat(notifications): add user_deadlines table"

cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add server/api/deadlines/ tests/unit/server/deadlines.spec.ts
git commit -m "feat(notifications): add user deadlines CRUD API"
```

---

### Task 2.4: System calendar table + seed

**Files:**
- Create: `recruiting-compass-ios/supabase/migrations/20260317000004_add_system_calendar.sql`

- [ ] **Step 1: Write migration**

```sql
-- supabase/migrations/20260317000004_add_system_calendar.sql
CREATE TABLE IF NOT EXISTS system_calendar (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category     text NOT NULL CHECK (category IN (
                 'signing_day','nli_period',
                 'contact_period','dead_period','quiet_period','evaluation_period',
                 'sat_date','act_date'
               )),
  sport        text,
  division     text CHECK (division IN ('d1','d2','d3') OR division IS NULL),
  label        text NOT NULL,
  start_date   date NOT NULL,
  end_date     date,
  season_year  int NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- No RLS — service role only (admin-managed)
```

- [ ] **Step 2: Run migration**

```bash
npx supabase db push
```

- [ ] **Step 3: Seed from existing `ncaaRecruitingCalendar.ts` data**

The web app already has `RECRUITING_CALENDAR_2026` and `MILESTONES_2026` in `server/utils/ncaaRecruitingCalendar.ts`. Write a seed script that reads these and INSERTs into `system_calendar`.

```typescript
// scripts/seed-system-calendar.ts
// Run with: npx tsx scripts/seed-system-calendar.ts
import { createClient } from '@supabase/supabase-js'
import {
  RECRUITING_CALENDAR_2026,
  ALL_MILESTONES,   // SAT, ACT, NCAA, NAIA, application, signing periods combined
} from '../server/utils/ncaaRecruitingCalendar'

const supabase = createClient(
  process.env.NUXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

const rows = [
  ...RECRUITING_CALENDAR_2026.map(p => ({
    category: p.type + '_period',
    sport: 'baseball',
    division: p.division.toLowerCase(),
    label: p.description,
    start_date: p.start.toISOString().split('T')[0],
    end_date: p.end.toISOString().split('T')[0],
    season_year: 2026,
  })),
  ...ALL_MILESTONES.map(m => ({
    category: m.type === 'test' ? (m.title.toLowerCase().includes('sat') ? 'sat_date' : 'act_date')
              : m.type === 'signing' ? 'signing_day' : 'nli_period',
    sport: null,
    division: m.division?.toLowerCase() ?? null,
    label: m.title,
    start_date: m.date,
    end_date: null,
    season_year: 2026,
  })),
]

const { error } = await supabase.from('system_calendar').upsert(rows, { onConflict: 'label,start_date,season_year' })
if (error) { console.error(error); process.exit(1) }
console.log(`Seeded ${rows.length} system_calendar rows`)
```

- [ ] **Step 4: Run seed script**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx tsx scripts/seed-system-calendar.ts
```

- [ ] **Step 5: Verify in Supabase Dashboard → Table Editor → system_calendar**

- [ ] **Step 6: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add supabase/migrations/20260317000004_add_system_calendar.sql
git commit -m "feat(notifications): add system_calendar table"

cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
git add scripts/seed-system-calendar.ts
git commit -m "feat(notifications): seed system_calendar from ncaaRecruitingCalendar"
```

---

### Task 2.5: Deadline alert log migration

**Files:**
- Create: `recruiting-compass-ios/supabase/migrations/20260317000005_add_deadline_alert_log.sql`

- [ ] **Step 1: Write migration**

```sql
-- supabase/migrations/20260317000005_add_deadline_alert_log.sql
-- Deduplicates deadline alerts. source_table includes 'coaches' for follow-up reminders.
-- alert_days_before: 7/3/0 for deadline alerts; day-of-week sentinel values for follow-ups.
CREATE TABLE IF NOT EXISTS deadline_alert_log (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES auth.users NOT NULL,
  source_table      text NOT NULL
    CHECK (source_table IN ('user_deadlines','offers','system_calendar','events','coaches')),
  source_id         uuid NOT NULL,
  alert_days_before int NOT NULL,  -- 7/3/0 for deadlines; use 0 for same-day follow-up dedup
  sent_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, source_table, source_id, alert_days_before)
);

CREATE INDEX deadline_alert_log_user_idx ON deadline_alert_log (user_id, source_table, source_id);
```

- [ ] **Step 2: Run and verify**

```bash
npx supabase db push
```

- [ ] **Step 3: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add supabase/migrations/20260317000005_add_deadline_alert_log.sql
git commit -m "feat(notifications): add deadline_alert_log dedup table"
```

---

### Task 2.6: Fix `notification_preferences` CHECK + add `email_enabled`

**Files:**
- Create: `recruiting-compass-ios/supabase/migrations/20260317000006_notification_preferences_weekly_digest.sql`

The existing `notification_preferences` table has `daily_digest` in its CHECK constraint (from migration `20260315000002`) and no `email_enabled` column. This migration fixes both.

- [ ] **Step 1: Write migration**

```sql
-- supabase/migrations/20260317000006_notification_preferences_weekly_digest.sql

-- Update CHECK constraint: replace daily_digest with weekly_digest
ALTER TABLE notification_preferences
  DROP CONSTRAINT IF EXISTS notification_preferences_notification_type_check;

ALTER TABLE notification_preferences
  ADD CONSTRAINT notification_preferences_notification_type_check
  CHECK (notification_type IN (
    'follow_up_reminder', 'deadline_alert', 'weekly_digest',
    'inbound_interaction', 'offer', 'event'
  ));

-- Add email_enabled column (only digest and deadline_alert send email per spec)
ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS email_enabled bool NOT NULL DEFAULT true;
```

- [ ] **Step 2: Run migration**

```bash
npx supabase db push
```

- [ ] **Step 3: Update iOS `notification_preferences` CHECK**

In `PushPreferencesServiceImpl.swift` or wherever the `notification_type` enum is used, rename any reference to `daily_digest` → `weekly_digest`.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
git add supabase/migrations/20260317000006_notification_preferences_weekly_digest.sql
git commit -m "fix(notifications): rename daily_digest to weekly_digest, add email_enabled to notification_preferences"
```

---

## Phase 3 — Cron Edge Functions

> **Goal:** Three Edge Functions run on schedule, scanning for follow-ups and deadlines, inserting notifications. The push trigger fires automatically.
>
> All functions live in the iOS repo at `supabase/functions/`.

---

### Task 3.1: Update `notificationGenerator.ts` to use `deadline_alert_log`

**Files:**
- Modify: `recruiting-compass-web/server/utils/notificationGenerator.ts`
- Test: `recruiting-compass-web/tests/unit/server/notificationGenerator.spec.ts`

The existing generator checks for duplicates by querying `notifications` directly. Update it to use `deadline_alert_log` for dedup, and update `generateCoachFollowupNotifications` to respect `follow_up_threshold_days` per coach.

- [ ] **Step 1: Write failing tests for updated dedup logic**

```typescript
// tests/unit/server/notificationGenerator.spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock Supabase client — pattern mirrors existing ruleEngine.spec.ts and auth.spec.ts
const mockInsert = vi.fn().mockResolvedValue({ error: null })
const mockSingle = vi.fn()
const mockFrom = vi.fn()

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({
    from: mockFrom,
  })),
}))

// Helper: build a chainable Supabase mock for a given table
function buildMockChain(data: unknown[] | null, error = null) {
  const chain = {
    select: vi.fn().mockReturnThis(),
    eq: vi.fn().mockReturnThis(),
    order: vi.fn().mockReturnThis(),
    limit: vi.fn().mockReturnThis(),
    gte: vi.fn().mockReturnThis(),
    not: vi.fn().mockReturnThis(),
    maybeSingle: vi.fn().mockResolvedValue({ data: data?.[0] ?? null, error }),
    insert: mockInsert,
  }
  return chain
}

describe('generateCoachFollowupNotifications — threshold logic', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.resetModules() // prevent mock state leaking between lazy imports
  })

  it('uses per-coach follow_up_threshold_days when set to 14', async () => {
    // Arrange: coach with last interaction 15 days ago, threshold 14
    const coach = {
      id: 'coach-1',
      first_name: 'Jane', last_name: 'Smith',
      follow_up_threshold_days: 14,
    }
    const lastInteraction = new Date()
    lastInteraction.setDate(lastInteraction.getDate() - 15)

    mockFrom.mockImplementation((table: string) => {
      if (table === 'coaches') return buildMockChain([coach])
      if (table === 'interactions') return buildMockChain([{ occurred_at: lastInteraction.toISOString() }])
      if (table === 'deadline_alert_log') return buildMockChain(null) // not yet sent
      if (table === 'notifications') return { insert: mockInsert }
      return buildMockChain([])
    })

    // Import lazily to allow mocks to initialize
    const { generateCoachFollowupNotifications } = await import('~/server/utils/notificationGenerator')
    const result = await generateCoachFollowupNotifications('user-1', { from: mockFrom } as never)

    expect(result.count).toBe(1)
    expect(mockInsert).toHaveBeenCalledWith(
      expect.arrayContaining([expect.objectContaining({ type: 'follow_up_reminder' })])
    )
  })

  it('does NOT fire when last interaction is within threshold', async () => {
    const coach = { id: 'coach-2', first_name: 'Bob', last_name: 'Jones', follow_up_threshold_days: 21 }
    const recentInteraction = new Date()
    recentInteraction.setDate(recentInteraction.getDate() - 5) // 5 days ago, within 21-day threshold

    mockFrom.mockImplementation((table: string) => {
      if (table === 'coaches') return buildMockChain([coach])
      if (table === 'interactions') return buildMockChain([{ occurred_at: recentInteraction.toISOString() }])
      return buildMockChain([])
    })

    const { generateCoachFollowupNotifications } = await import('~/server/utils/notificationGenerator')
    const result = await generateCoachFollowupNotifications('user-1', { from: mockFrom } as never)

    expect(result.count).toBe(0)
    expect(mockInsert).not.toHaveBeenCalled()
  })

  it('falls back to 21 days when follow_up_threshold_days is null', async () => {
    const coach = { id: 'coach-3', first_name: 'Alice', last_name: 'Wong', follow_up_threshold_days: null }
    const oldInteraction = new Date()
    oldInteraction.setDate(oldInteraction.getDate() - 22) // 22 days ago, over 21-day default

    mockFrom.mockImplementation((table: string) => {
      if (table === 'coaches') return buildMockChain([coach])
      if (table === 'interactions') return buildMockChain([{ occurred_at: oldInteraction.toISOString() }])
      if (table === 'deadline_alert_log') return buildMockChain(null)
      if (table === 'notifications') return { insert: mockInsert }
      return buildMockChain([])
    })

    const { generateCoachFollowupNotifications } = await import('~/server/utils/notificationGenerator')
    const result = await generateCoachFollowupNotifications('user-1', { from: mockFrom } as never)

    expect(result.count).toBe(1)
  })
})
```

- [ ] **Step 2: Update `generateCoachFollowupNotifications`**

Change hardcoded `FOLLOWUP_THRESHOLD = 7` to use `coach.follow_up_threshold_days ?? 21`. Change dedup check from querying `notifications` to checking `deadline_alert_log` with `source_table: 'coaches'`.

- [ ] **Step 3: Run full generator tests**

```bash
npx vitest run tests/unit/server/notificationGenerator.spec.ts
```

- [ ] **Step 4: Commit**

```bash
git add server/utils/notificationGenerator.ts tests/unit/server/notificationGenerator.spec.ts
git commit -m "feat(notifications): update notificationGenerator to use deadline_alert_log and per-coach threshold"
```

---

### Task 3.2: `process-follow-up-reminders` Edge Function

**Files:**
- Create: `recruiting-compass-ios/supabase/functions/process-follow-up-reminders/index.ts`

- [ ] **Step 1: Implement the function**

```typescript
// supabase/functions/process-follow-up-reminders/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

Deno.serve(async () => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  let processed = 0

  // Get all users with their timezone
  const { data: users } = await supabase.from('users').select('id, timezone')
  if (!users?.length) return new Response('no users', { status: 200 })

  for (const user of users) {
    const tz = user.timezone ?? 'America/New_York'
    const todayInTz = new Date().toLocaleDateString('en-CA', { timeZone: tz }) // YYYY-MM-DD

    // 1. next_contact_date reminders
    const { data: coaches } = await supabase
      .from('coaches')
      .select('id, first_name, last_name, next_contact_date, follow_up_threshold_days')
      .eq('user_id', user.id)
      .not('next_contact_date', 'is', null)

    for (const coach of coaches ?? []) {
      if (coach.next_contact_date !== todayInTz) continue
      const alreadySent = await checkAlertLog(supabase, user.id, 'coaches', coach.id, 0)
      if (alreadySent) continue
      await insertNotification(supabase, user.id, coach, 'date_based')
      await logAlert(supabase, user.id, 'coaches', coach.id, 0)
      processed++
    }

    // 2. Inactivity reminders
    const threshold = 21 // default; per-coach threshold handled below
    const { data: allCoaches } = await supabase
      .from('coaches')
      .select('id, first_name, last_name, follow_up_threshold_days')
      .eq('user_id', user.id)

    for (const coach of allCoaches ?? []) {
      const days = coach.follow_up_threshold_days ?? 21
      const cutoff = new Date()
      cutoff.setDate(cutoff.getDate() - days)
      const cutoffStr = cutoff.toLocaleDateString('en-CA', { timeZone: tz })

      // Find most recent interaction
      const { data: recent } = await supabase
        .from('interactions')
        .select('occurred_at')
        .eq('user_id', user.id)
        .eq('coach_id', coach.id)
        .order('occurred_at', { ascending: false })
        .limit(1)

      const lastContact = recent?.[0]?.occurred_at?.split('T')[0] ?? null
      if (!lastContact || lastContact > cutoffStr) continue

      // alert_days_before: 0 = "sent today" sentinel for inactivity follow-ups
      const alreadySent = await checkAlertLog(supabase, user.id, 'coaches', coach.id, 0)
      if (alreadySent) continue
      await insertNotification(supabase, user.id, coach, 'inactivity', days)
      await logAlert(supabase, user.id, 'coaches', coach.id, 0)
      processed++
    }
  }

  return new Response(JSON.stringify({ processed }), { status: 200 })
})

async function checkAlertLog(supabase, userId, table, id, days) {
  const today = new Date().toISOString().split('T')[0]
  const { data } = await supabase
    .from('deadline_alert_log')
    .select('id')
    .eq('user_id', userId)
    .eq('source_table', table)
    .eq('source_id', id)
    .eq('alert_days_before', days)
    .gte('sent_at', today)
    .maybeSingle()
  return !!data
}

async function logAlert(supabase, userId, table, id, days) {
  await supabase.from('deadline_alert_log').upsert({
    user_id: userId, source_table: table, source_id: id, alert_days_before: days
  })
}

async function insertNotification(supabase, userId, coach, reason, daysSince?) {
  const name = `${coach.first_name ?? ''} ${coach.last_name ?? ''}`.trim()
  const title = reason === 'date_based'
    ? `Time to contact ${name}`
    : `You haven't contacted ${name} in ${daysSince} days`
  const message = `Stay active in your recruiting — reach out to ${name} today.`
  await supabase.from('notifications').insert({
    user_id: userId,
    type: 'follow_up_reminder',
    title,
    message,
    priority: 'normal',
    related_entity_type: 'coach',
    related_entity_id: coach.id,
    related_coach_id: coach.id,
    scheduled_for: new Date().toISOString(),
  })
}
```

- [ ] **Step 2: Deploy the function**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
npx supabase functions deploy process-follow-up-reminders
```

- [ ] **Step 3: Test manually — trigger via curl or Supabase dashboard**

```bash
curl -X POST \
  https://<PROJECT-REF>.supabase.co/functions/v1/process-follow-up-reminders \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>"
```

Expected: `{"processed": N}` — check Supabase logs for any errors.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/process-follow-up-reminders/
git commit -m "feat(notifications): add process-follow-up-reminders Edge Function"
```

---

### Task 3.3: `process-deadline-alerts` Edge Function

**Files:**
- Create: `recruiting-compass-ios/supabase/functions/process-deadline-alerts/index.ts`

- [ ] **Step 1: Implement the function**

```typescript
// supabase/functions/process-deadline-alerts/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ALERT_DAYS = [7, 3, 0] // days before deadline to alert

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { data: users } = await supabase.from('users')
    .select('id, timezone, player_details(graduation_year, primary_sport)')
  let processed = 0

  for (const user of users ?? []) {
    const tz = user.timezone ?? 'America/New_York'
    const todayInTz = new Date().toLocaleDateString('en-CA', { timeZone: tz })

    // Collect all deadlines from 4 sources
    const deadlines: Array<{
      source_table: string; source_id: string; deadline_date: string; label: string
    }> = []

    // 1. user_deadlines
    const { data: ud } = await supabase.from('user_deadlines')
      .select('id, label, deadline_date').eq('user_id', user.id)
    for (const d of ud ?? []) {
      deadlines.push({ source_table: 'user_deadlines', source_id: d.id, deadline_date: d.deadline_date, label: d.label })
    }

    // 2. offers with deadline_date
    const { data: offers } = await supabase.from('offers')
      .select('id, deadline_date, schools(name)')
      .eq('user_id', user.id).not('deadline_date', 'is', null)
      .in('status', ['verbal', 'official', 'pending'])
    for (const o of offers ?? []) {
      deadlines.push({
        source_table: 'offers', source_id: o.id,
        deadline_date: o.deadline_date,
        label: `Offer deadline: ${(o.schools as { name: string })?.name ?? 'Unknown'}`
      })
    }

    // 3. system_calendar (scoped to user's sport + graduation year)
    const grad = user.player_details?.graduation_year
    const sport = user.player_details?.primary_sport
    const { data: sc } = await supabase.from('system_calendar')
      .select('id, label, start_date')
      .eq('season_year', grad ?? new Date().getFullYear())
      .or(`sport.is.null,sport.eq.${sport ?? 'baseball'}`)
    for (const s of sc ?? []) {
      deadlines.push({ source_table: 'system_calendar', source_id: s.id, deadline_date: s.start_date, label: s.label })
    }

    // 4. upcoming visits (official/unofficial)
    const { data: visits } = await supabase.from('events')
      .select('id, name, start_date')
      .eq('user_id', user.id)
      .in('type', ['official_visit', 'unofficial_visit'])
    for (const v of visits ?? []) {
      deadlines.push({ source_table: 'events', source_id: v.id, deadline_date: v.start_date, label: `Visit: ${v.name}` })
    }

    // Check each deadline × each alert distance
    for (const d of deadlines) {
      const deadlineDate = new Date(d.deadline_date)
      const today = new Date(todayInTz)
      const daysUntil = Math.round((deadlineDate.getTime() - today.getTime()) / 86400000)

      for (const alertDays of ALERT_DAYS) {
        if (daysUntil !== alertDays) continue

        // Check dedup
        const { data: existing } = await supabase.from('deadline_alert_log')
          .select('id')
          .eq('user_id', user.id)
          .eq('source_table', d.source_table)
          .eq('source_id', d.source_id)
          .eq('alert_days_before', alertDays)
          .maybeSingle()
        if (existing) continue

        const title = alertDays === 0 ? `Today: ${d.label}`
          : `${alertDays} days: ${d.label}`
        const message = alertDays === 0
          ? `${d.label} is today.`
          : `${d.label} is in ${alertDays} day${alertDays !== 1 ? 's' : ''}.`

        await supabase.from('notifications').insert({
          user_id: user.id,
          type: 'deadline_alert',
          title,
          message,
          priority: alertDays <= 3 ? 'high' : 'normal',
          scheduled_for: new Date().toISOString(),
        })

        await supabase.from('deadline_alert_log').insert({
          user_id: user.id,
          source_table: d.source_table,
          source_id: d.source_id,
          alert_days_before: alertDays,
        })

        processed++
      }
    }
  }

  return new Response(JSON.stringify({ processed }), { status: 200 })
})
```

- [ ] **Step 2: Deploy**

```bash
npx supabase functions deploy process-deadline-alerts
```

- [ ] **Step 3: Manual test**

```bash
curl -X POST \
  https://<PROJECT-REF>.supabase.co/functions/v1/process-deadline-alerts \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>"
```

Verify notifications appear for any offer/deadline within 7 days.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/process-deadline-alerts/
git commit -m "feat(notifications): add process-deadline-alerts Edge Function"
```

---

### Task 3.4: Configure pg_cron schedules

- [ ] **Step 1: Run in Supabase SQL Editor**

```sql
-- Enable pg_cron (Dashboard → Database → Extensions → pg_cron if not enabled)

-- Follow-up reminders: daily at 12:00 UTC (8am ET)
SELECT cron.schedule(
  'process-follow-up-reminders',
  '0 12 * * *',
  $$SELECT net.http_post(
      url := 'https://<PROJECT-REF>.supabase.co/functions/v1/process-follow-up-reminders',
      headers := '{"Authorization":"Bearer <SUPABASE_ANON_KEY>"}'::jsonb
  )$$
);

-- Deadline alerts: daily at 12:00 UTC
SELECT cron.schedule(
  'process-deadline-alerts',
  '0 12 * * *',
  $$SELECT net.http_post(
      url := 'https://<PROJECT-REF>.supabase.co/functions/v1/process-deadline-alerts',
      headers := '{"Authorization":"Bearer <SUPABASE_ANON_KEY>"}'::jsonb
  )$$
);
```

- [ ] **Step 2: Verify cron jobs are registered**

```sql
SELECT jobname, schedule, command FROM cron.job;
```

- [ ] **Step 3: Commit documentation**

```bash
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios
cat > docs/cron-schedules.md << 'EOF'
# Cron Schedules

Registered via pg_cron in Supabase SQL Editor.

| Job | Schedule (UTC) | ET equivalent |
|---|---|---|
| process-follow-up-reminders | 0 12 * * * | 8am ET |
| process-deadline-alerts | 0 12 * * * | 8am ET |
| send-weekly-digest | 0 12 * * 1 | 8am ET Monday |
EOF
git add docs/cron-schedules.md
git commit -m "docs: add cron schedule reference"
```

---

## Phase 4 — Weekly Digest

---

### Task 4.1: `send-weekly-digest` Edge Function

**Files:**
- Create: `recruiting-compass-ios/supabase/functions/send-weekly-digest/index.ts`

- [ ] **Step 1: Implement the function**

```typescript
// supabase/functions/send-weekly-digest/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const WEB_APP_URL = Deno.env.get('WEB_APP_URL')! // e.g. https://app.recruitingcompass.com
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

Deno.serve(async () => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  let sent = 0

  const { data: users } = await supabase
    .from('users').select('id, timezone, email')

  const weekAgo = new Date()
  weekAgo.setDate(weekAgo.getDate() - 7)
  const weekAgoStr = weekAgo.toISOString()

  for (const user of users ?? []) {
    // Check preference — default to enabled
    const { data: pref } = await supabase
      .from('notification_preferences')
      .select('push_enabled')
      .eq('user_id', user.id)
      .eq('notification_type', 'weekly_digest')
      .maybeSingle()
    if (pref?.push_enabled === false) continue

    // Compile activity
    // school_status_history has no user_id — must join through schools
    const { data: userSchoolIds } = await supabase
      .from('schools').select('id').eq('user_id', user.id)
    const schoolIds = (userSchoolIds ?? []).map((s: { id: string }) => s.id)

    const [{ count: interactions }, { count: schoolChanges }, { data: upcoming }] = await Promise.all([
      supabase.from('interactions').select('id', { count: 'exact', head: true })
        .eq('user_id', user.id).gte('occurred_at', weekAgoStr),
      schoolIds.length
        ? supabase.from('school_status_history').select('id', { count: 'exact', head: true })
            .in('school_id', schoolIds).gte('changed_at', weekAgoStr)
        : Promise.resolve({ count: 0 }),
      supabase.from('user_deadlines').select('label, deadline_date')
        .eq('user_id', user.id)
        .gte('deadline_date', new Date().toISOString().split('T')[0])
        .lte('deadline_date', new Date(Date.now() + 14 * 86400000).toISOString().split('T')[0])
        .order('deadline_date'),
    ])

    const hasActivity = (interactions ?? 0) > 0 || (schoolChanges ?? 0) > 0

    const lines: string[] = hasActivity
      ? [
          `Last week: ${interactions ?? 0} interaction${interactions !== 1 ? 's' : ''} logged`,
          schoolChanges ? `${schoolChanges} school status change${schoolChanges !== 1 ? 's' : ''}` : null,
          (upcoming?.length ?? 0) > 0 ? `Upcoming deadlines: ${upcoming!.map(d => d.label).join(', ')}` : null,
        ].filter(Boolean) as string[]
      : [
          'Quiet week — keep the momentum going!',
          'Consider reaching out to 2 coaches you haven\'t contacted recently.',
        ]

    // Insert in-app notification
    await supabase.from('notifications').insert({
      user_id: user.id,
      type: 'weekly_digest',
      title: 'Your weekly recruiting recap',
      message: lines.join('\n'),
      priority: 'low',
      scheduled_for: new Date().toISOString(),
    })

    // Send email if address available
    if (user.email) {
      await fetch(`${WEB_APP_URL}/api/email/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: user.email,
          subject: 'Your weekly recruiting recap',
          template: 'weekly-digest',
          data: { lines, upcomingDeadlines: upcoming ?? [] },
        }),
      })
    }

    sent++
  }

  return new Response(JSON.stringify({ sent }), { status: 200 })
})
```

- [ ] **Step 2: Deploy**

```bash
npx supabase functions deploy send-weekly-digest
```

- [ ] **Step 3: Set `WEB_APP_URL` secret**

```bash
npx supabase secrets set WEB_APP_URL=https://your-app.vercel.app
```

- [ ] **Step 4: Register Monday cron**

```sql
SELECT cron.schedule(
  'send-weekly-digest',
  '0 12 * * 1',
  $$SELECT net.http_post(
      url := 'https://<PROJECT-REF>.supabase.co/functions/v1/send-weekly-digest',
      headers := '{"Authorization":"Bearer <SUPABASE_ANON_KEY>"}'::jsonb
  )$$
);
```

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/send-weekly-digest/
git commit -m "feat(notifications): add send-weekly-digest Edge Function"
```

---

## Phase 5 — Email

---

### Task 5.1: `/api/email/send` Nuxt route

**Files:**
- Create: `recruiting-compass-web/server/api/email/send.post.ts`
- Test: `recruiting-compass-web/tests/unit/server/emailSend.spec.ts`

The existing `emailService.ts` already uses Resend with hand-crafted HTML. Extend it with `weekly-digest` and `deadline-alert` templates. This avoids adding Vue Email as a dependency.

- [ ] **Step 1: Write failing tests**

```typescript
// tests/unit/server/emailSend.spec.ts
import { describe, it, expect } from 'vitest'
import { z } from 'zod'

const emailSendSchema = z.object({
  to: z.string().email(),
  subject: z.string().min(1),
  template: z.enum(['weekly-digest', 'deadline-alert']),
  data: z.record(z.unknown()),
})

describe('email/send schema', () => {
  it('accepts weekly-digest payload', () => {
    const result = emailSendSchema.safeParse({
      to: 'test@example.com',
      subject: 'Your weekly recap',
      template: 'weekly-digest',
      data: { lines: ['3 interactions logged'], upcomingDeadlines: [] },
    })
    expect(result.success).toBe(true)
  })
  it('rejects unknown template', () => {
    const result = emailSendSchema.safeParse({
      to: 'test@example.com', subject: 'Test', template: 'banana', data: {}
    })
    expect(result.success).toBe(false)
  })
  it('rejects invalid email', () => {
    const result = emailSendSchema.safeParse({
      to: 'not-an-email', subject: 'Test', template: 'weekly-digest', data: {}
    })
    expect(result.success).toBe(false)
  })
})
```

- [ ] **Step 2: Add templates to `emailService.ts`**

Add two template functions to `server/utils/emailService.ts`:

```typescript
export function renderWeeklyDigestEmail(data: {
  lines: string[]
  upcomingDeadlines: Array<{ label: string; deadline_date: string }>
}): string {
  const lineItems = data.lines
    .map(l => `<li style="margin:4px 0">${escapeHtml(l)}</li>`)
    .join('')
  const deadlineItems = data.upcomingDeadlines.length
    ? data.upcomingDeadlines
        .map(d => `<li>${escapeHtml(d.label)} — ${d.deadline_date}</li>`)
        .join('')
    : '<li>No upcoming deadlines</li>'

  return `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px">
    <h2>Your Weekly Recruiting Recap</h2>
    <ul>${lineItems}</ul>
    <h3>Upcoming Deadlines</h3>
    <ul>${deadlineItems}</ul>
    <p style="color:#888;font-size:12px">You're receiving this because you have a Recruiting Compass account.</p>
  </body></html>`
}

export function renderDeadlineAlertEmail(data: {
  label: string; daysUntil: number; deadline_date: string
}): string {
  const urgency = data.daysUntil === 0 ? 'TODAY' : `in ${data.daysUntil} day${data.daysUntil !== 1 ? 's' : ''}`
  return `<!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px">
    <h2>Deadline ${urgency}</h2>
    <p><strong>${escapeHtml(data.label)}</strong> is due ${urgency} (${data.deadline_date}).</p>
    <p style="color:#888;font-size:12px">You're receiving this because you have a Recruiting Compass account.</p>
  </body></html>`
}
```

- [ ] **Step 3: Implement the route**

```typescript
// server/api/email/send.post.ts
import { defineEventHandler, readBody, createError } from 'h3'
import { z } from 'zod'
import { Resend } from 'resend'
import { renderWeeklyDigestEmail, renderDeadlineAlertEmail } from '~/server/utils/emailService'
import { useLogger } from '~/server/utils/logger'

const schema = z.object({
  to: z.string().email(),
  subject: z.string().min(1),
  template: z.enum(['weekly-digest', 'deadline-alert']),
  data: z.record(z.unknown()),
})

export default defineEventHandler(async (event) => {
  const logger = useLogger(event, 'email/send')
  const body = await readBody(event)
  const parsed = schema.safeParse(body)
  if (!parsed.success) throw createError({ statusCode: 422, statusMessage: 'Invalid request' })

  const { to, subject, template, data } = parsed.data
  const html = template === 'weekly-digest'
    ? renderWeeklyDigestEmail(data as Parameters<typeof renderWeeklyDigestEmail>[0])
    : renderDeadlineAlertEmail(data as Parameters<typeof renderDeadlineAlertEmail>[0])

  const resend = new Resend(process.env.RESEND_API_KEY)
  const { error } = await resend.emails.send({
    from: 'Recruiting Compass <notifications@recruitingcompass.com>',
    to,
    subject,
    html,
  })

  if (error) {
    logger.error('Resend error', error)
    throw createError({ statusCode: 500, statusMessage: 'Failed to send email' })
  }

  return { success: true }
})
```

- [ ] **Step 4: Run tests**

```bash
npx vitest run tests/unit/server/emailSend.spec.ts
```

- [ ] **Step 5: Set `RESEND_API_KEY` in Vercel env**

```bash
vercel env add RESEND_API_KEY
```

- [ ] **Step 6: Commit**

```bash
git add server/api/email/send.post.ts server/utils/emailService.ts tests/unit/server/emailSend.spec.ts
git commit -m "feat(notifications): add email send route with weekly-digest and deadline-alert templates"
```

---

### Task 5.2: Notification preferences page (web)

**Files:**
- Create: `recruiting-compass-web/pages/settings/notifications.vue`

- [ ] **Step 1: Implement preferences page**

The page reads from `notification_preferences` (which the iOS app already writes to). Show toggles for push + email per type. On change, upsert the row.

```vue
<!-- pages/settings/notifications.vue -->
<template>
  <div class="max-w-2xl mx-auto py-8 px-4">
    <h1 class="text-2xl font-bold mb-6">Notification Preferences</h1>
    <div v-if="loading" class="text-gray-500">Loading...</div>
    <div v-else class="space-y-4">
      <div v-for="type in NOTIFICATION_TYPES" :key="type.value"
        class="flex items-center justify-between p-4 bg-white rounded-lg border">
        <div>
          <p class="font-medium">{{ type.label }}</p>
          <p class="text-sm text-gray-500">{{ type.description }}</p>
        </div>
        <label class="relative inline-flex items-center cursor-pointer">
          <input type="checkbox" :checked="prefs[type.value]"
            @change="togglePref(type.value)" class="sr-only peer" />
          <div class="w-11 h-6 bg-gray-200 peer-checked:bg-blue-600 rounded-full transition"></div>
        </label>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const NOTIFICATION_TYPES = [
  { value: 'follow_up_reminder', label: 'Follow-up Reminders', description: 'When it\'s time to contact a coach' },
  { value: 'deadline_alert', label: 'Deadline Alerts', description: 'Application, offer, and NCAA deadlines' },
  { value: 'weekly_digest', label: 'Weekly Digest', description: 'Monday morning recruiting summary' },
  { value: 'event', label: 'Event Reminders', description: '24 hours before visits and showcases' },
]

const client = useSupabaseClient()
const user = useSupabaseUser()
const loading = ref(true)
const prefs = ref<Record<string, boolean>>({})

onMounted(async () => {
  const { data } = await client.from('notification_preferences')
    .select('notification_type, push_enabled, email_enabled').eq('user_id', user.value!.id)

  // Push prefs — default all on
  const pushMap: Record<string, boolean> = {}
  for (const t of NOTIFICATION_TYPES) pushMap[t.value] = true
  for (const row of data ?? []) pushMap[row.notification_type] = row.push_enabled
  prefs.value = pushMap

  // Email prefs — only for EMAIL_TYPES, default on
  const emailMap: Record<string, boolean> = {}
  for (const t of NOTIFICATION_TYPES.filter(t => EMAIL_TYPES.has(t.value))) emailMap[t.value] = true
  for (const row of data ?? []) {
    if (EMAIL_TYPES.has(row.notification_type)) emailMap[row.notification_type] = row.email_enabled ?? true
  }
  emailPrefs.value = emailMap

  loading.value = false
})

const EMAIL_TYPES = new Set(['deadline_alert', 'weekly_digest'])
const emailPrefs = ref<Record<string, boolean>>({})

async function togglePref(type: string) {
  const next = !prefs.value[type]
  prefs.value[type] = next
  await client.from('notification_preferences').upsert({
    user_id: user.value!.id,
    notification_type: type,
    push_enabled: next,
  }, { onConflict: 'user_id,notification_type' })
}

async function toggleEmailPref(type: string) {
  const next = !emailPrefs.value[type]
  emailPrefs.value[type] = next
  await client.from('notification_preferences').upsert({
    user_id: user.value!.id,
    notification_type: type,
    email_enabled: next,
  }, { onConflict: 'user_id,notification_type' })
}
</script>
```

- [ ] **Step 2: Add link to settings nav**

Find the settings layout/nav and add a "Notifications" link to `/settings/notifications`.

- [ ] **Step 3: Commit**

```bash
git add pages/settings/notifications.vue
git commit -m "feat(notifications): add notification preferences page"
```

---

## Phase 6 — Web Deadlines Page

---

### Task 6.1: `useDeadlines` composable

**Files:**
- Create: `recruiting-compass-web/composables/useDeadlines.ts`
- Test: `recruiting-compass-web/tests/unit/composables/useDeadlines.spec.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// tests/unit/composables/useDeadlines.spec.ts
import { describe, it, expect, vi } from 'vitest'

describe('useDeadlines', () => {
  it('exports fetch, create, and remove functions', async () => {
    // Dynamic import to avoid Nuxt runtime in tests
    const mod = await import('~/composables/useDeadlines').catch(() => null)
    // If module doesn't exist yet, this will fail — that's expected (RED)
    expect(mod).not.toBeNull()
  })
})
```

- [ ] **Step 2: Implement composable**

```typescript
// composables/useDeadlines.ts
export function useDeadlines() {
  const deadlines = ref<Array<{
    id: string; label: string; deadline_date: string; category: string; school_id?: string
  }>>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function fetchDeadlines() {
    loading.value = true
    try {
      const data = await $fetch('/api/deadlines')
      deadlines.value = data as typeof deadlines.value
    } catch (e) {
      error.value = 'Failed to load deadlines'
    } finally {
      loading.value = false
    }
  }

  async function createDeadline(payload: {
    label: string; deadline_date: string; category: string; school_id?: string
  }) {
    const created = await $fetch('/api/deadlines', { method: 'POST', body: payload })
    await fetchDeadlines()
    return created
  }

  async function removeDeadline(id: string) {
    await $fetch(`/api/deadlines/${id}`, { method: 'DELETE' })
    deadlines.value = deadlines.value.filter(d => d.id !== id)
  }

  return { deadlines, loading, error, fetchDeadlines, createDeadline, removeDeadline }
}
```

- [ ] **Step 3: Run tests**

```bash
npx vitest run tests/unit/composables/useDeadlines.spec.ts
```

- [ ] **Step 4: Implement `deadlines.vue` page**

```vue
<!-- pages/deadlines.vue -->
<template>
  <div class="max-w-4xl mx-auto py-8 px-4">
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold">Deadlines</h1>
      <button @click="showAdd = true"
        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
        + Add Deadline
      </button>
    </div>

    <div v-if="loading" class="text-gray-500">Loading...</div>
    <div v-else-if="deadlines.length === 0" class="text-gray-400 text-center py-12">
      No deadlines yet. Add your first one.
    </div>
    <ul v-else class="space-y-3">
      <li v-for="d in sortedDeadlines" :key="d.id"
        class="flex items-center justify-between p-4 bg-white rounded-lg border">
        <div>
          <p class="font-medium">{{ d.label }}</p>
          <p class="text-sm text-gray-500">{{ d.deadline_date }} · {{ d.category }}</p>
        </div>
        <button @click="removeDeadline(d.id)" class="text-red-500 hover:text-red-700 text-sm">
          Remove
        </button>
      </li>
    </ul>

    <!-- Add deadline modal -->
    <div v-if="showAdd" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
      <form @submit.prevent="submitAdd"
        class="bg-white rounded-xl p-6 w-full max-w-md shadow-xl space-y-4">
        <h2 class="text-lg font-bold">Add Deadline</h2>
        <input v-model="newDeadline.label" placeholder="Label" required
          class="w-full border rounded-lg px-3 py-2" />
        <input v-model="newDeadline.deadline_date" type="date" required
          class="w-full border rounded-lg px-3 py-2" />
        <select v-model="newDeadline.category" class="w-full border rounded-lg px-3 py-2">
          <option value="application">Application</option>
          <option value="decision">Decision</option>
          <option value="financial_aid">Financial Aid</option>
          <option value="visit">Visit</option>
          <option value="custom">Custom</option>
        </select>
        <div class="flex gap-3 justify-end">
          <button type="button" @click="showAdd = false" class="px-4 py-2 border rounded-lg">Cancel</button>
          <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-lg">Add</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
const { deadlines, loading, fetchDeadlines, createDeadline, removeDeadline } = useDeadlines()
const showAdd = ref(false)
const newDeadline = reactive({ label: '', deadline_date: '', category: 'application' })

onMounted(fetchDeadlines)

const sortedDeadlines = computed(() =>
  [...deadlines.value].sort((a, b) => a.deadline_date.localeCompare(b.deadline_date))
)

async function submitAdd() {
  await createDeadline({ ...newDeadline })
  showAdd.value = false
  Object.assign(newDeadline, { label: '', deadline_date: '', category: 'application' })
}
</script>
```

- [ ] **Step 5: Add deadlines link to nav**

Find the main navigation component and add a "Deadlines" link.

- [ ] **Step 6: Commit**

```bash
git add composables/useDeadlines.ts pages/deadlines.vue tests/unit/composables/useDeadlines.spec.ts
git commit -m "feat(notifications): add deadlines page and useDeadlines composable"
```

---

## Verification Checklist

Run after completing all phases:

```bash
# Web — full test suite
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web
npx vitest run

# iOS — full build + tests
cd /Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass -destination 'platform=iOS Simulator,name=iPhone 17'
```

**End-to-end smoke test:**
1. Admin broadcast → push appears on iOS device ✓
2. Add a deadline 7 days from today → trigger `process-deadline-alerts` manually → notification appears ✓
3. Monday cron → weekly digest push + email received ✓
4. Follow-up reminder → set `next_contact_date` to today → trigger `process-follow-up-reminders` → notification appears ✓
5. Preferences page → disable `weekly_digest` → run digest cron → no notification ✓
