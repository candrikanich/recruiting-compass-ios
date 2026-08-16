# Handoff: Notification Backend Jobs

**Date:** 2026-08-16  
**Status:** iOS UI complete, backend delivery missing  
**Priority:** Required before any notification feature can be called "working"

---

## Summary

The iOS app has a complete notification preferences UI and correctly persists all settings to Supabase. Device tokens are registered. The push notification receive/routing path works. **What does not exist is any backend job that reads those preferences and actually sends a notification.**

The toggles in the app are live data — but nothing ever consumes them.

---

## What's Already Built (iOS side)

### Supabase tables the app writes to

| Table | What's stored | Key columns |
|---|---|---|
| `preferences` | In-app + email settings (one JSON blob per user) | `user_id`, `category = 'notifications'`, `data` (JSON) |
| `notification_preferences` | Per-type push enabled/disabled | `user_id`, `notification_type`, `push_enabled` |
| `device_tokens` | APNs device tokens | `user_id`, `token`, `platform = 'ios'` |
| `notifications` | In-app notification inbox rows | `user_id`, `read_at`, `type`, `payload` |

### `preferences.data` JSON shape (category = `notifications`)

```json
{
  "followUpReminderDays": 7,
  "enableFollowUpReminders": true,
  "enableDeadlineAlerts": true,
  "enableDailyDigest": true,
  "enableInboundInteractionAlerts": true,
  "enableEmailNotifications": true,
  "emailOnlyHighPriority": false,
  "quietHoursStart": null,
  "quietHoursEnd": null
}
```

### `notification_preferences` rows (one per type per user)

`notification_type` values (from `NotificationType` enum):
- `follow_up_reminder`
- `deadline_alert`
- `weekly_digest`
- `inbound_interaction`
- `offer`
- `event`

### iOS bug fixed this session

`SettingsView.swift` was not passing `pushPreferencesService` to `NotificationPreferencesView`, so push toggle saves were silently no-ops. **Fixed** — `PushPreferencesServiceImpl(supabaseManager: .shared)` is now injected at `SettingsView.swift:244`.

---

## What Needs to Be Built (backend)

All of this lives outside the iOS repo — Supabase edge functions and/or `pg_cron` jobs.

### 1. Follow-up Reminders (`follow_up_reminder`)

**Trigger:** Scheduled (daily or hourly check)  
**Logic:**
1. For each user where `preferences.data->enableFollowUpReminders = true`
2. Find coaches in their list where last interaction was `> followUpReminderDays` ago
3. If a reminder hasn't been sent within `followUpReminderDays` already, fire push + insert `notifications` row
4. Respect `push_enabled` in `notification_preferences` for type `follow_up_reminder`
5. If `enableEmailNotifications = true`, also send email (respect `emailOnlyHighPriority` — follow-ups are not high-priority)

### 2. Deadline Alerts (`deadline_alert`)

**Trigger:** Scheduled (daily, morning)  
**Logic:**
1. For each user where `preferences.data->enableDeadlineAlerts = true`
2. Find deadlines (applications, offers, NCAA dates) at 7, 3, and 0 days out
3. Fire push + `notifications` row for each matching deadline
4. Respect `push_enabled` for type `deadline_alert`
5. Deadlines are high-priority — always send email if `enableEmailNotifications = true` (regardless of `emailOnlyHighPriority`)

### 3. Daily/Weekly Digest (`weekly_digest`)

**Trigger:** Scheduled (weekly, Monday morning per web UI description)  
**Logic:**
1. For each user where `preferences.data->enableDailyDigest = true` (note: model calls it "daily digest" but web labels it "weekly" — clarify with product which cadence is correct)
2. Summarize recruiting activity for the period
3. Fire push + `notifications` row
4. Respect `push_enabled` for type `weekly_digest`
5. Digest is high-priority context — send email if `enableEmailNotifications = true`

### 4. Inbound Contact Alerts (`inbound_interaction`)

**Trigger:** Database webhook — fires when a new row is inserted into `interactions` where the interaction is inbound (coach-initiated)  
**Logic:**
1. Check destination user's `preferences.data->enableInboundInteractionAlerts`
2. Fire push immediately + `notifications` row
3. Respect `push_enabled` for type `inbound_interaction`
4. Inbound contact is high-priority — send email if `enableEmailNotifications = true`

### 5. Offer Notifications (`offer`)

**Trigger:** Database webhook — fires when an offer row is created/updated  
**Logic:**
1. Fire push to the relevant user + `notifications` row
2. Respect `push_enabled` for type `offer`
3. Offers are high-priority — always email if `enableEmailNotifications = true`

### 6. Event Reminders (`event`)

**Trigger:** Scheduled (daily check) — fires 24 hours before events (visits, showcases)  
**Logic:**
1. Find events 24h out for each user
2. Fire push + `notifications` row
3. Respect `push_enabled` for type `event`

---

## Notification delivery implementation notes

### APNs push delivery
Each job needs to:
1. Look up `device_tokens` for the user (`platform = 'ios'`)
2. Call APNs with the device token
3. Payload should include a `destination` key that the app can route — see `NotificationDestinationParser.swift` for the expected payload shape

### In-app `notifications` table insert
Every push should also insert a row into `notifications` so it appears in the in-app inbox. The badge count is synced from unread `notifications` rows (`read_at IS NULL`).

### Web vs iOS schema divergence
The web UI (screenshot) shows per-notification email sub-toggles ("Also send email" under Deadline Alerts and Weekly Digest). The iOS model has a single global `enableEmailNotifications` + `emailOnlyHighPriority` flag. These may write to different storage. **Before building the backend jobs, confirm which schema is authoritative** — the backend should read from one source of truth.

---

## Files to reference in the iOS repo

| File | Purpose |
|---|---|
| `Features/Preferences/Models/NotificationSettings.swift` | Full shape of the in-app/email prefs blob |
| `Features/Notifications/Models/NotificationType.swift` | All notification type raw values |
| `Features/Preferences/Services/PushPreferencesServiceImpl.swift` | How iOS reads/writes `notification_preferences` |
| `Core/Services/PushNotificationManager.swift` | How device tokens are registered; APNs payload routing |
| `Core/Utilities/NotificationDestinationParser.swift` | Expected push payload shape for deep-link routing |
| `Core/Services/AppDelegate.swift` | Token registration entry point |
