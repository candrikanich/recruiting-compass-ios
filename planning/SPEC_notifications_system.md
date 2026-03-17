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
- User can override per coach (stored alongside coach record)
- Inactivity is measured from the most recent interaction date for that coach

**Timing:** Daily cron at 8am — scan all coaches for both conditions

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
- **Day of** — morning of the deadline (8am)

**Deduplication:** Track which alerts have fired per deadline (prevent re-send on cron re-run).

**Channels:** Push + Email

---

### 3. `weekly_digest`
A summary of the user's recruiting activity over the past week.

**Schedule:** Monday 8am (fixed — no user control over timing)

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
Since inbound interactions are entered manually by the user, a notification on creation is redundant — same reasoning as `offer`. Type retained in the enum for future use (e.g. automatic coach email detection).

---

### 5. `event`
Reminds the user of an upcoming scheduled event (campus visit, showcase, camp, etc.)

**Trigger:** Scheduled cron scans upcoming events — fires reminder **24 hours before** the event start time

**Channels:** Push only

**Note:** No notification on event creation — user just created it, they know.

---

### 6. `offer` — **INACTIVE in v1**
Since offers are entered manually by the user, a notification on creation is redundant. Removed from active triggers. The type remains in the enum for future use (e.g. coach-initiated offer via a future integration).

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

**Email service:** TBD (Resend recommended — native Vercel Marketplace integration)

---

## User Preferences

One source of truth: `notification_preferences` table (already created).

### What users control

| Setting | Granularity | Default |
|---|---|---|
| Push enabled per type | Per notification type | All on |
| Email enabled per type | Per notification type (digest + deadlines only) | On |
| Inactivity threshold | Per coach | 21 days |

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
- Testing the full push pipeline
- Product announcements ("New feature: offers tracking")
- System alerts ("We'll be down for maintenance at 2am")

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

### Cron Config (`supabase/functions/`)
All scheduled functions use Supabase's pg_cron or Vercel Cron calling Edge Function endpoints.

### Database Changes
| Migration | Purpose |
|---|---|
| `add_device_tokens` | ✅ Done |
| `add_notification_preferences` | ✅ Done |
| `add_push_trigger` | ✅ Done |
| `add_deadline_alert_tracking` | Track which deadline × alert distance combos have already fired |
| `add_coach_inactivity_threshold` | Per-coach `follow_up_threshold_days` column |

### Web App Changes
| Page | Work |
|---|---|
| `/notifications` | Enhance from read-only to include mark-read, delete, filter by type |
| `/settings/notifications` | Preferences page — reads/writes `notification_preferences` table |
| `/admin/notifications` | Broadcast tool (admin-only) |

### iOS Changes
Already done:
- `PushNotificationManager` ✅
- `NotificationPreferencesView` ✅
- In-app notification list ✅
- Deep link routing ✅

Remaining:
- Per-coach inactivity threshold UI (coach detail or preferences)
- Handle `weekly_digest` notification type deep link (route to notifications list)

---

## Implementation Order

### Phase 1 — Test the pipeline (1 session)
1. Admin broadcast page in web app
2. Verify push delivers end-to-end

### Phase 2 — Event-driven notifications (1–2 sessions)
1. `inbound_interaction` Postgres trigger
2. Per-coach inactivity threshold column + iOS UI

### Phase 3 — Scheduled notifications (2 sessions)
1. `process-follow-up-reminders` Edge Function + cron
2. `process-deadline-alerts` Edge Function + cron + dedup tracking

### Phase 4 — Digest + Email (1–2 sessions)
1. `send-weekly-digest` Edge Function + cron
2. Email delivery via Resend for digest + deadline_alert types
3. Web app `/settings/notifications` preferences page

### Phase 5 — Web app notification management
1. Enhance `/notifications` page (mark read, delete, filter)

---

## Open Questions

- What timezone do we use for scheduled sends? User's local timezone (requires storing it) or a fixed zone (e.g. ET)?
- For the weekly digest email — do we build a React Email template or plain text first?
- Should `next_contact_date` on coaches already exist, or is that a new field to add?
- Deadline alert dedup: store in a separate table or as a flag on the deadline record?
