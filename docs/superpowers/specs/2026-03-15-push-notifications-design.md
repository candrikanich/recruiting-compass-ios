# Push Notifications — Design Spec

**Date:** 2026-03-15
**Status:** Approved

---

## Overview

The in-app notification center (list, filter, read/unread, delete) is already built and backed by a Supabase `notifications` table. This spec covers the missing delivery layer: APNs push notifications triggered automatically when a notification record is inserted, with per-user per-type preferences.

**Users:** Parents and student athletes (13+). Standard APNs permission flow, no COPPA concerns.

---

## What's Already Built

- `AppNotification` model with all fields (`type`, `priority`, `read_at`, `email_sent`, `related_*`, etc.)
- `NotificationsServiceImpl` — CRUD against Supabase `notifications` table
- `NotificationsListViewModel` — filtering, search, read/unread, deep link destination parsing via `parseDestination` (currently private)
- `NotificationsListView`, `NotificationCard`, filter chips, bulk actions
- Notification types: `follow_up_reminder`, `deadline_alert`, `daily_digest`, `inbound_interaction`, `offer`, `event`

---

## Architecture

### Delivery Flow

```
notifications INSERT
      │
      ▼
Postgres trigger → pg_net (async, does NOT block INSERT transaction)
      │
      ▼
Edge Function: send-push-notification  (runs as service role, bypasses RLS)
      ├── query notification_preferences (push_enabled?)
      │     └── no row found = treat as push_enabled: true (default-on)
      ├── query device_tokens for user (may be multiple devices)
      └── send APNs HTTP/2 push to each token
            ├── 200 OK → mark sent_at if ≥1 device succeeded
            ├── 410 Gone → delete stale token, continue to next
            └── other error → log, continue to next device (no retry — deliberate)
                  │
                  ▼
            App receives push
                  ├── Foreground → in-app banner via UNUserNotificationCenter
                  ├── Background tap → deep link via NotificationDestinationParser
                  └── Terminated tap → deep link on launch
```

**Transient APNs failures (429, 503, 5xx):** No retry. Push is a best-effort channel — the in-app notification center always shows every notification regardless of push delivery. Retries add complexity for marginal gain at this stage.

**pg_net async behavior:** The trigger fires `pg_net` which queues the HTTP call in a background worker. The `notifications` INSERT completes immediately — Edge Function failures never roll back or delay the write.

---

## iOS App Changes

### New: `NotificationDestinationParser` (Core/Utilities/)

Extract `parseDestination` from `NotificationsListViewModel` (currently `private`) into a standalone pure function in `Core/Utilities/NotificationDestinationParser.swift`. This allows both `PushNotificationManager` and `NotificationsListViewModel` to use it without a layering violation (`Sendable` Core service cannot depend on a `@MainActor` feature ViewModel).

```swift
enum NotificationDestinationParser {
    static func destination(from notification: AppNotification) -> NotificationDestination?
    static func destination(fromPayload payload: [AnyHashable: Any]) -> NotificationDestination?
}
```

`NotificationsListViewModel` updates its call sites to use `NotificationDestinationParser` instead of its own private method.

### New: `PushNotificationManager` (Core/Services/)

Singleton service. Owns all APNs interaction.

```swift
protocol PushNotificationManaging: Sendable {
    func requestPermission() async
    func registerDeviceToken(_ token: Data) async
    func deleteDeviceToken() async   // call on logout
    func handleNotificationTap(payload: [AnyHashable: Any]) -> NotificationDestination?
    func syncBadgeCount() async      // call on app foreground
    func clearBadge()                // call when notification center opened
}
```

**Responsibilities:**
- **Permission:** Request push permission once after onboarding completes — never on cold launch. Record denied state for Settings prompt.
- **Token registration:** Upsert device token to `device_tokens` on every app launch (tokens rotate). Delete token from `device_tokens` on logout — hook into `AuthManager.logout()`.
- **`UNUserNotificationCenterDelegate`:**
  - Foreground: show banner + sound + badge (`completionHandler(.banner, .sound, .badge)`)
  - Background/terminated tap: call `NotificationDestinationParser.destination(fromPayload:)` to resolve deep link
- **Badge count:** `syncBadgeCount()` queries unread count from `notifications` table and sets `UNUserNotificationCenter.setBadgeCount(_:)`. `clearBadge()` sets to 0 — called when notification center view appears.
- **`nonisolated deinit {}`** required — per project-wide requirement to prevent macOS 26.x / Darwin 25.x double-free crash during test teardown.

### New: `NotificationPreferencesViewModel` + `NotificationPreferencesView` (Features/Preferences/ or Features/Settings/)

Toggle list — one row per `NotificationType`. Reads/writes `notification_preferences` table via a new `NotificationPreferencesService`. Reachable from the Settings screen.

**Seeding on first login:** Insert a row for each `NotificationType` raw value with `push_enabled = true` using `INSERT ... ON CONFLICT DO NOTHING`. Never overwrites existing preferences. Call site: `AuthManager` after a successful login, before returning to the caller.

**Denied OS permission state:** If `UNUserNotificationCenter.authorizationStatus == .denied`, show "Enable in iOS Settings" prompt instead of toggles.

### Updated: `TheRecruitingCompassApp.swift`

- Instantiate `PushNotificationManager` as a singleton at app start
- Set as `UNUserNotificationCenter.current().delegate`
- Call `requestPermission()` after onboarding completion
- Call `syncBadgeCount()` in `.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification))`

### Updated: `AuthManager.logout()`

After Supabase sign-out, call `pushNotificationManager.deleteDeviceToken()` to remove the current device token from `device_tokens`. This prevents pushes from arriving on a logged-out device.

---

## Supabase Schema

### `device_tokens` table

```sql
CREATE TABLE device_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users NOT NULL,
  token       text NOT NULL,
  platform    text NOT NULL DEFAULT 'ios',
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE (user_id, token)
);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Users read/write only their own tokens
CREATE POLICY "device_tokens: users manage own"
  ON device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

### `notification_preferences` table

```sql
CREATE TABLE notification_preferences (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid REFERENCES auth.users NOT NULL,
  notification_type   text NOT NULL
    CHECK (notification_type IN (
      'follow_up_reminder', 'deadline_alert', 'daily_digest',
      'inbound_interaction', 'offer', 'event'
    )),
  push_enabled        bool NOT NULL DEFAULT true,
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now(),
  UNIQUE (user_id, notification_type)
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users read/write only their own preferences
CREATE POLICY "notification_preferences: users manage own"
  ON notification_preferences FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

**No preference row = push enabled.** The Edge Function treats a missing row as `push_enabled: true`. This is the correct UX default — new users receive all push types until they explicitly disable one.

**Schema evolution:** When a new `NotificationType` is added to the Swift enum, update the `CHECK` constraint in a migration and add the new type to the seeding logic.

---

## Edge Function: `send-push-notification`

**Location:** `supabase/functions/send-push-notification/index.ts`

**Auth:** Runs as service role (bypasses RLS). The service role key is **never embedded in SQL** — it is injected automatically by Supabase's function invoker when triggered via `supabase_functions.http_request`. No secret appears in DDL.

**Trigger:**
```sql
CREATE OR REPLACE FUNCTION notify_on_notification_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM supabase_functions.http_request(
    'https://<project-ref>.supabase.co/functions/v1/send-push-notification',
    'POST',
    '{"Content-Type":"application/json"}',
    to_jsonb(NEW)::text,
    '5000'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER push_on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW EXECUTE FUNCTION notify_on_notification_insert();
```

The `supabase_functions.http_request` call runs via `pg_net` — asynchronous, never blocks the INSERT.

**Logic:**
1. Parse inserted `notification` row from request body
2. Query `notification_preferences` for `(user_id, notification_type)`:
   - Row found and `push_enabled = false` → exit 200, no push
   - Row not found → continue (default-on)
3. Query `device_tokens` for `user_id` — if none, exit 200
4. Query unread badge count:
   ```sql
   SELECT COUNT(*) FROM notifications
   WHERE user_id = $1 AND read_at IS NULL
   ```
5. Build APNs payload per token:
   ```json
   {
     "aps": {
       "alert": { "title": "<notification.title>", "body": "<notification.message>" },
       "badge": <unread_count>,
       "sound": "default"
     },
     "notification_id": "<id>",
     "related_entity_type": "<type>",
     "related_entity_id": "<id>"
   }
   ```
6. Send to each device token via APNs HTTP/2 (JWT auth using `.p8` key from Supabase secrets):
   - **200 OK:** success, continue
   - **410 Gone:** delete token from `device_tokens`, continue to next
   - **Any other error:** log error, continue to next device (no retry)
7. If **at least one device** received the push successfully, update `notifications.sent_at = now()`
8. Return 200 regardless of partial failures (push is best-effort)

**Supabase Secrets required:**
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_PRIVATE_KEY` (full contents of `.p8` file — newlines preserved)
- `APNS_BUNDLE_ID` — `com.chrisandrikanich.TheRecruitingCompass`

---

## Error Handling

| Scenario | Handling |
|---|---|
| User denies push permission | `PushNotificationManager` records denied state; preferences screen shows "Enable in iOS Settings" prompt |
| APNs token invalid (410) | Edge Function deletes stale token from `device_tokens`, continues to next device |
| APNs transient error (429, 503, 5xx) | Log and skip — no retry. In-app notification center always shows the record. |
| Edge Function timeout | pg_net timeout — notification still in DB, push silently dropped |
| No device token for user | Edge Function exits early after step 3 |
| All push disabled by user | Edge Function exits early after step 2 |
| User logged out — token stale | Logout deletes token; no future pushes on that device |

---

## Testing

**Unit tests:**
- `PushNotificationManagerTests` — mock `UNUserNotificationCenter`; verify token upsert on launch, token deletion on logout, badge sync, `clearBadge` resets to 0
- `NotificationPreferencesViewModelTests` — toggle state reads/writes service, seeding is idempotent
- `NotificationDestinationParserTests` — all entity types + action URL patterns resolve correctly (extract from existing `NotificationsListViewModel` tests)

**Integration tests:**
- Device token upsert idempotency: same token + same user → single row, no duplicate
- Token deleted on logout: row absent from `device_tokens` after `AuthManager.logout()`
- Preference seed on first login: all 6 types present with `push_enabled = true`
- Preference seed is idempotent: running seed twice doesn't overwrite user changes

**Edge Function tests (Supabase CLI local):**
- Insert a notification row directly → verify Edge Function is invoked and push payload is correct
- Preference `push_enabled = false` → verify function exits without sending
- No device token → verify function exits cleanly
- 410 from mock APNs → verify token removed from `device_tokens`

**Manual verification:**
- Push received in foreground → in-app banner shown
- Push tapped from background → navigates to correct entity
- Push tapped from terminated state → app opens and navigates
- Disabling a type in preferences → no push fired for that type
- Badge shows correct unread count; clears when notification center opened
- Logout → no further pushes on that device

---

## Out of Scope

- Email delivery (fields exist on `AppNotification`; separate spec)
- Notification scheduling / digest batching
- Rich push (images, action buttons) — plain text for now
- Android
- Retry logic for transient APNs failures
