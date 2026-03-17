# Notifications System Spec
_Created: 2026-03-17_

---

## Overview

A unified notification system across iOS (push + in-app) and web (in-app + email) that alerts users to recruiting activity requiring their attention. Notifications are stored in the `notifications` table and delivered via push (iOS) and email (digest + deadlines only).

This spec covers: triggers, timing, channels, user preferences, admin tooling, and implementation roadmap.

---

## Principals & Scope

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
- Cron Edge Functions (or Supabase cron) call this endpoint when email delivery is needed
- Keeps Vue Email rendering in Node/Nuxt where it belongs; Edge Functions stay thin

**Templates needed:**
- `deadline-alert.vue` — school name, deadline type, days remaining, CTA button
- `weekly-digest.vue` — activity summary table, upcoming deadlines, suggested actions

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

**Deadline types tracked:**
- User-entered deadlines (attached to a school or event)
- NCAA signing day / NLI dates (system-known calendar)
- Application deadlines (entered by user per school)
- Official/unofficial visit windows

**Alert cadence:** Three notifications per deadline:
- **7 days out** — early warning
- **3 days out** — last chance to act
- **Day of** — morning of the deadline (8am user timezone)

**Deduplication:** `deadline_alert_log` table — one row per `(deadline_id, alert_days_before)`. Query: fire alert only if no matching row exists. Insert row immediately after firing.

**Channels:** Push + Email

---

### 3. `weekly_digest`
A summary of the user's recruiting activity over the past week.

**Schedule:** Monday 8am user timezone (fixed — no user control over timing)

**Content:**
- Interactions logged last week (count by coach/school)
- Upcoming deadlines in the next 14 days
- Follow-up reminders due this week
- School status changes last week
- If activity is low: include a default "quiet week" message with a suggested action (e.g. "Consider reaching out to 2 coaches you haven't contacted in a while")

**Suppress if empty:** No — always send, but populate with helpful default content on quiet weeks

**Channels:** Push + Email

---

### 4. `inbound_interaction` — **INACTIVE in v1**
Inbound interactions are entered manually — user already knows. Type retained for future use (e.g. automatic coach email detection).

---

### 5. `event`
Reminds the user of an upcoming scheduled event (campus visit, showcase, camp, etc.)

**Trigger:** Daily cron scans upcoming events — fires reminder **24 hours before** the event start time

**Channels:** Push only

**Note:** No notification on event creation — user just created it, they know.

---

### 6. `offer` — **INACTIVE in v1**
Offers are entered manually — notification is redundant. Type retained for future use (e.g. coach-initiated offer via future integration).

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
- No per-platform divergence for type-level toggles
- Push device token registration is per-device (already in `device_tokens` table)

---

## Admin Broadcast (App Owner Only)

A page in the web app (admin-gated) to send a notification to a specific user or all users.

**Use cases:**
- Testing the full push pipeline end-to-end
- Product announcements ("New feature: offers tracking")
- System alerts

**Implementation:**
- Web app API route: `POST /api/admin/notifications/broadcast`
- Inserts rows into `notifications` table (one per target user)
- Existing push trigger fires automatically for each insert
- UI: simple form — select target (specific user or all), type, title, message

**Auth:** Admin-only — gate with a role check on the Supabase session

---

## Infrastructure Required

### Supabase Edge Functions (new)
| Function | Schedule | Purpose |
|---|---|---|
| `process-follow-up-reminders` | Daily 8am | Check `next_contact_date` + inactivity per coach |
| `process-deadline-alerts` | Daily 8am | Check all deadlines at 7d / 3d / 0d marks |
| `send-weekly-digest` | Monday 8am | Compile weekly summary, INSERT notifications |
| `send-push-notification` | On demand (trigger) | APNs delivery — **already built** ✅ |

### Nuxt Server Routes (new)
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
| `add_user_timezone` | Needed | `timezone text` column on users/profiles table |
| `add_coach_next_contact_date` | Needed | `next_contact_date date` + `follow_up_threshold_days int` on coaches |
| `add_deadline_alert_log` | Needed | `(deadline_id, alert_days_before, sent_at)` dedup table |

### Web App Changes
| Page | Work |
|---|---|
| `/notifications` | Enhance from read-only: mark-read, delete, filter by type |
| `/settings/notifications` | Preferences page — reads/writes `notification_preferences` table |
| `/admin/notifications` | Broadcast tool (admin-only) |

### iOS Changes
Already done:
- `PushNotificationManager` ✅
- `NotificationPreferencesView` ✅
- In-app notification list ✅
- Deep link routing ✅

Remaining:
- `next_contact_date` + `follow_up_threshold_days` UI on coach detail
- Handle `weekly_digest` deep link (route to notifications list)

---

## Implementation Order

### Phase 1 — Test the pipeline (1 session)
1. Admin broadcast page in web app
2. Verify push delivers end-to-end

### Phase 2 — Data model (1 session)
1. Migration: `add_user_timezone` + derive from existing `HomeLocation` data
2. Migration: `add_coach_next_contact_date` + `follow_up_threshold_days`
3. iOS: `next_contact_date` UI on coach detail

### Phase 3 — Scheduled push notifications (2 sessions)
1. Migration: `add_deadline_alert_log`
2. `process-follow-up-reminders` Edge Function + cron
3. `process-deadline-alerts` Edge Function + cron

### Phase 4 — Event reminders (1 session)
1. Update `process-follow-up-reminders` or separate `process-event-reminders` cron

### Phase 5 — Email (1–2 sessions)
1. Install Resend via Vercel Marketplace, add to Nuxt
2. `POST /api/email/send` Nuxt route + Vue Email templates
3. `send-weekly-digest` Edge Function calls Nuxt email route
4. Deadline alert email wired into `process-deadline-alerts`
5. Web app `/settings/notifications` preferences page
