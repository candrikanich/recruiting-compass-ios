# Notifications System Spec
_Created: 2026-03-17_

---

## Overview

A unified notification system across iOS (push + in-app) and web (in-app + email) that alerts users to recruiting activity requiring their attention. Notifications are stored in the `notifications` table and delivered via push (iOS) and email (digest + deadlines only).

This spec covers: triggers, timing, channels, user preferences, admin tooling, and implementation roadmap.

---

## Principles & Scope

- **Each user** (athlete or parent) has their own independent notification feed and preferences
- **No shared family feed** — family members are notified individually
- **App owner only** admin broadcast — no coach-facing notifications in v1

---

## Timezone

Users are US-only. Four zones supported: `America/New_York`, `America/Chicago`, `America/Denver`, `America/Los_Angeles`. Default: `America/New_York`.

**Source:** `HomeLocation` already stores `zip`, `latitude`, and `longitude`. Derive timezone from **state** (extracted from zip or reverse geocode) using a static state→timezone map. Store result as `timezone text` on the user profile row.

**When to derive:** Once, when the user saves their home location. Re-derive only if home location changes. Never compute per-send.

**Static map approach** (no external API needed):
- ET states: ME, NH, VT, MA, RI, CT, NY, NJ, PA, DE, MD, DC, VA, WV, NC, SC, GA, FL, OH, MI, IN, KY, TN
- CT states: ND, SD, NE, KS, MN, IA, MO, WI, IL, AR, LA, MS, AL, OK, TX
- MT states: MT, WY, CO, NM, AZ, UT, ID (non-Pacific)
- PT states: WA, OR, CA, NV
- Everything else → default ET

---

## Email Stack

**Provider:** Resend (native Vercel Marketplace, single API key, delivery analytics built in)

**Templates:** Vue Email (`vue-email` / `@vue-email/render`) — the Vue equivalent of React Email. Components render to email-safe HTML server-side in Nuxt.

**Architecture:** Email sending lives in the **Nuxt app**, not in Supabase Edge Functions.
- Nuxt server route: `POST /api/email/send` — accepts `{ to, subject, template, data }`
- Cron Edge Functions call this endpoint when email delivery is needed
- Keeps Vue Email rendering in Node/Nuxt where it belongs; Edge Functions stay thin

**Templates needed:**
- `deadline-alert.vue` — school name, deadline type, days remaining, CTA button
- `weekly-digest.vue` — activity summary table, upcoming deadlines, suggested actions

---

## Deadline Data Model

Deadlines come from four sources. The `process-deadline-alerts` cron queries all four.

### Sources

| Source | Table | Key Field | Notes |
|---|---|---|---|
| Offer acceptance deadlines | `offers` | `deadline_date` | Already exists ✅ |
| Visit windows | `events` | `start_date` | `official_visit`, `unofficial_visit` types ✅ |
| User-created deadlines | `user_deadlines` | `deadline_date` | New table — application, decision, custom |
| NCAA calendar + testing dates | `system_calendar` | `start_date` | New table — admin-managed annually |

### `user_deadlines` table
User-created deadlines optionally scoped to a school.

```sql
CREATE TABLE user_deadlines (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users NOT NULL,
  school_id     uuid REFERENCES schools(id),  -- optional
  label         text NOT NULL,
  deadline_date date NOT NULL,
  category      text NOT NULL CHECK (category IN (
                  'application', 'decision', 'financial_aid', 'visit', 'custom'
                )),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
```

### `system_calendar` table
Admin-managed annual dates: NCAA recruiting periods, signing days, testing dates. Updated once per year by the app owner. No public API exists — NCAA and testing org sites (ncaa.org, collegeboard.org, act.org) publish these annually as HTML only.

**Sources to seed from:**
- NCAA recruiting calendars: ncaa.org/sports (sport + division specific)
- NLI signing dates: nationalletter.org/signingDates
- SAT test dates: collegeboard.org
- ACT test dates: act.org

```sql
CREATE TABLE system_calendar (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category     text NOT NULL CHECK (category IN (
                 'signing_day', 'nli_period',
                 'contact_period', 'dead_period', 'quiet_period', 'evaluation_period',
                 'sat_date', 'act_date'
               )),
  sport        text,      -- NULL = applies to all sports
  division     text,      -- 'd1', 'd2', 'd3', NULL = all divisions
  label        text NOT NULL,
  start_date   date NOT NULL,
  end_date     date,      -- NULL for single-day events
  season_year  int NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
-- Service role only — no user RLS needed
```

**Scoping for users:** The cron filters `system_calendar` rows by:
- `sport` matches `player_details.primary_sport` (or is NULL)
- `division` matches any division in the user's school list (or is NULL)
- `season_year` = current year based on `player_details.graduation_year`

### `deadline_alert_log` table
Dedup tracking — prevents re-firing the same alert on cron re-runs.

```sql
CREATE TABLE deadline_alert_log (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES auth.users NOT NULL,
  source_table      text NOT NULL,  -- 'user_deadlines','offers','system_calendar','events'
  source_id         uuid NOT NULL,
  alert_days_before int NOT NULL,   -- 7, 3, 0
  sent_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, source_table, source_id, alert_days_before)
);
```

### `process-deadline-alerts` query logic

```
FOR each user:
  tz = user.timezone (default 'America/New_York')
  today = CURRENT_DATE AT TIME ZONE tz

  Collect deadlines from:
    user_deadlines WHERE user_id = ?
    offers WHERE user_id = ? AND deadline_date IS NOT NULL
              AND status IN ('verbal', 'official', 'pending')
    system_calendar WHERE season_year = graduation_year
                     AND (sport = primary_sport OR sport IS NULL)
                     AND (division IN user_school_divisions OR division IS NULL)
    events WHERE user_id = ? AND type IN ('official_visit','unofficial_visit')

  FOR each deadline WHERE days_until IN (7, 3, 0):
    IF NOT EXISTS in deadline_alert_log:
      INSERT into notifications
      INSERT into deadline_alert_log
```

---

## Notification Types

### 1. `follow_up_reminder`
Reminds the user to reach out to a coach they haven't contacted recently.

**Triggers (two independent mechanisms):**

| Mechanism | Logic |
|---|---|
| User-set date | Coach has a `next_contact_date`; notification fires on that date at 8am user timezone |
| Inactivity detection | No interaction logged with a coach in X days → fire reminder |

**Inactivity threshold:**
- System default: **21 days**
- User can override per coach via `follow_up_threshold_days` column on the coach record
- Inactivity is measured from the most recent interaction date for that coach

**Timing:** Daily cron at 8am user timezone

**Channels:** Push only

---

### 2. `deadline_alert`
Warns the user that an important recruiting deadline is approaching.

**Sources:** `user_deadlines`, `offers.deadline_date`, `system_calendar`, `events` — see Deadline Data Model above.

**Alert cadence:** Three notifications per deadline:
- **7 days out** — early warning
- **3 days out** — last chance to act
- **Day of** — morning of the deadline (8am user timezone)

**Deduplication:** `deadline_alert_log` — one row per `(user_id, source_table, source_id, alert_days_before)`.

**Channels:** Push + Email

---

### 3. `weekly_digest`
A summary of the user's recruiting activity over the past week.

**Schedule:** Monday 8am user timezone (fixed — no user control)

**Content:**
- Interactions logged last week (count by coach/school)
- Upcoming deadlines in the next 14 days
- Follow-up reminders due this week
- School status changes last week
- Quiet week fallback: "Consider reaching out to 2 coaches you haven't contacted in a while"

**Suppress if empty:** No — always send with default content on quiet weeks

**Channels:** Push + Email

---

### 4. `inbound_interaction` — **INACTIVE in v1**
Inbound interactions are entered manually — user already knows. Type retained for future use (e.g. automatic coach email detection).

---

### 5. `event`
Reminds the user of an upcoming scheduled event (campus visit, showcase, camp, etc.)

**Trigger:** Daily cron — fires reminder **24 hours before** the event start time

**Channels:** Push only

**Note:** No notification on event creation — user just created it, they know.

---

### 6. `offer` — **INACTIVE in v1**
Offers are entered manually — notification is redundant. Type retained for future use.

---

## Channels

| Type | Push | In-App | Email |
|---|---|---|---|
| `follow_up_reminder` | ✅ | ✅ | — |
| `deadline_alert` | ✅ | ✅ | ✅ |
| `weekly_digest` | ✅ | ✅ | ✅ |
| `inbound_interaction` | — | — | — |
| `event` | ✅ | ✅ | — |
| `offer` | — | — | — |

---

## User Preferences

One source of truth: `notification_preferences` table (already created).

### What users control

| Setting | Granularity | Default |
|---|---|---|
| Push enabled per type | Per notification type | All on |
| Email enabled per type | Per notification type (digest + deadlines only) | On |
| Inactivity threshold | Per coach (`follow_up_threshold_days`) | 21 days |

### What users do NOT control
- Digest send day/time (Monday 8am, fixed)
- Deadline alert cadence (7d / 3d / day-of, fixed)
- Quiet hours (delegated to iOS Focus / system DND)

### Preference sync
- iOS preferences view writes to `notification_preferences` table
- Web app preferences page reads the same rows
- Push device token registration is per-device (`device_tokens` table)

---

## Admin Broadcast (App Owner Only)

A page in the web app (admin-gated) to send a notification to a specific user or all users.

**Use cases:** Pipeline testing, product announcements, system alerts

**Implementation:**
- `POST /api/admin/notifications/broadcast` — inserts rows into `notifications` table
- Existing push trigger fires automatically for each insert
- UI: select target (user or all), type, title, message

**Auth:** Admin role check on the Supabase session

---

## Infrastructure Required

### Supabase Edge Functions
| Function | Schedule | Purpose |
|---|---|---|
| `send-push-notification` | On demand (trigger) | APNs delivery — **already built** ✅ |
| `process-follow-up-reminders` | Daily 8am UTC | Check `next_contact_date` + inactivity per coach |
| `process-deadline-alerts` | Daily 8am UTC | Scan all 4 deadline sources at 7d/3d/0d marks |
| `send-weekly-digest` | Monday 8am UTC | Compile weekly summary, INSERT notifications |

> **Note:** Cron runs at 8am UTC and filters by user timezone when evaluating "is today the day" — this avoids running 4 separate cron jobs per timezone.

### Nuxt Server Routes
| Route | Purpose |
|---|---|
| `POST /api/email/send` | Render Vue Email template + deliver via Resend |
| `POST /api/admin/notifications/broadcast` | Admin-only notification broadcast |

### Database Migrations

| Migration | Status | Purpose |
|---|---|---|
| `add_device_tokens` | ✅ Done | APNs token storage |
| `add_notification_preferences` | ✅ Done | Per-type push/email toggles |
| `add_push_trigger` | ✅ Done | Fires Edge Function on notifications INSERT |
| `add_user_timezone` | Needed | `timezone text` on user profile |
| `add_coach_next_contact_date` | ✅ Done | `next_contact_date date` + `follow_up_threshold_days int` on coaches |
| `add_user_deadlines` | Needed | User-created deadline table |
| `add_system_calendar` | Needed | Admin-managed NCAA + testing dates |
| `add_deadline_alert_log` | Needed | Dedup tracking across all deadline sources |

### Web App Changes
| Page | Work |
|---|---|
| `/notifications` | Enhance: mark-read, delete, filter by type |
| `/settings/notifications` | Preferences page — reads/writes `notification_preferences` |
| `/admin/notifications` | Broadcast tool (admin-only) |
| `/deadlines` (new) | User-created deadlines CRUD — add/edit/delete `user_deadlines` rows |

### iOS Changes

Already done:
- `PushNotificationManager` ✅
- `NotificationPreferencesView` ✅
- In-app notification list ✅
- Deep link routing ✅

Remaining:
- `next_contact_date` + `follow_up_threshold_days` UI on coach detail
- `user_deadlines` CRUD (add/edit deadlines per school or standalone)
- Handle `weekly_digest` deep link → route to notifications list

---

## Implementation Order

### Phase 1 — Test the pipeline (1 session)
1. Admin broadcast page in web app
2. Verify push delivers end-to-end

### Phase 2 — Data model (1 session)
1. Migration: `add_user_timezone` + derive from existing `HomeLocation` data
2. Migration: `add_coach_next_contact_date`
3. Migration: `add_user_deadlines`
4. Migration: `add_system_calendar` + seed with current year NCAA/testing dates
5. iOS: `next_contact_date` UI on coach detail

### Phase 3 — Scheduled push notifications (2 sessions)
1. Migration: `add_deadline_alert_log`
2. `process-follow-up-reminders` Edge Function + cron
3. `process-deadline-alerts` Edge Function + cron (queries all 4 sources)
4. `process-event-reminders` logic (24h before event — fold into deadline alerts cron)

### Phase 4 — Digest (1 session)
1. `send-weekly-digest` Edge Function + cron

### Phase 5 — Email (1–2 sessions)
1. Install Resend via Vercel Marketplace
2. `POST /api/email/send` Nuxt route + Vue Email templates
3. Wire email into `process-deadline-alerts` and `send-weekly-digest`
4. Web app `/settings/notifications` preferences page

### Phase 6 — Web app deadline management (1 session)
1. `/deadlines` page — CRUD for `user_deadlines`
2. Enhance `/notifications` page (mark-read, delete, filter)
