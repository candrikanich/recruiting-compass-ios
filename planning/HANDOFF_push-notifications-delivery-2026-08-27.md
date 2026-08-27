# Handoff — Push Notification Delivery (APNs) is not wired

**Date:** 2026-08-27
**Reported:** Inbound coach contact/interest created in-app notifications, but **no APNs push arrived on iOS**. In-app notification list + web bell show the items fine.
**Verdict:** Not an iOS bug. **The backend never sends a push.** Tokens are collected and never consumed. This is primarily **web/backend** work, with a few iOS verification tasks.

---

## Root cause

The pipeline is missing its delivery stage:

```
inbound contact/interest  →  INSERT notifications row  →  sendNotificationEmail()  ✅
                                        │
                                        └─►  APNs push  ❌  NOTHING sends this
```

- **iOS registration WORKS.** `device_tokens` holds **10 iOS tokens** (newest 2026-08-25). `PushNotificationManager.swift` upserts on `(user_id, token)`; `AppDelegate` implements `didRegisterForRemoteNotificationsWithDeviceToken` + `didFailToRegisterForRemoteNotificationsWithError`.
- **Backend creates the notification + emails.** `server/api/public/profile/[slug]/{contact,interest}.post.ts` insert into `notifications` and call `sendNotificationEmail`.
- **No APNs sender exists anywhere.** grep across `server/`, `supabase/functions/` (empty — no edge functions), and crons found **zero** APNs/push-send code. `notifications` rows are written; nothing reads `device_tokens` to push.

So every code path that creates a `notifications` row is a silent push no-op.

---

## Current-state facts (verified this session)

| Piece | State | Evidence |
|---|---|---|
| `device_tokens` table | exists, RLS "users manage own", unique `(user_id, token)`, `platform` default `ios` | `supabase/migrations/00000000000000_baseline.sql:1111` |
| Registered tokens | **10 iOS**, newest 2026-08-25 | live DB query |
| iOS token upsert | present | `Core/Services/PushNotificationManager.swift:79` `.from("device_tokens").upsert(...)` |
| iOS receiver/registration | present | `AppDelegate.swift`, `PushNotificationManaging.swift` |
| iOS entitlement | `aps-environment = development` | `TheRecruitingCompass.entitlements` |
| APNs topic (bundle id) | `com.chrisandrikanich.TheRecruitingCompass` | `project.pbxproj:526` |
| Backend APNs sender | **MISSING** | no matches in `server/`, no edge functions, no cron |
| Notification creation | multiple sites (public contact/interest endpoints, crons, `useNotifications.createNotification`) | grep |

---

## The fix — build a push-delivery service (backend)

**Recommended architecture: Supabase Database Webhook on `notifications` INSERT → Edge Function → APNs HTTP/2.**

Trigger on the row insert, not at each call site — notifications are created in several places (public endpoints, crons, composable). A single choke point on `notifications` INSERT covers them all and can't be forgotten by a new writer.

1. **Supabase Edge Function** `push-fanout` (net-new — `supabase/functions/` is currently empty):
   - Invoked by a **Database Webhook** on `INSERT` into `public.notifications`.
   - Reads the new row's `user_id`, looks up `device_tokens` where `user_id = row.user_id`.
   - For each token, sends an APNs request over HTTP/2 to `api.push.apple.com` (prod) / `api.sandbox.push.apple.com` (sandbox) using **token-based auth (.p8 auth key + Key ID + Team ID)** — simpler than cert-based and doesn't expire yearly.
   - `apns-topic: com.chrisandrikanich.TheRecruitingCompass`, `apns-push-type: alert`, `apns-priority: 10`.
   - Payload: `{ aps: { alert: { title, body }, sound: "default", badge: <unread count> }, notificationId, relatedEntityType, relatedEntityId }` — carry the ids so a tap can deep-link (iOS `NotificationDestinationParser` already exists to route these).
   - On APNs `410 Unregistered` / `BadDeviceToken` → delete that `device_tokens` row (prune dead tokens).

2. **Sandbox vs production is the likely gotcha.** The 10 registered tokens were minted by a **`development` (sandbox)** build. Sandbox tokens are rejected by the **production** APNs host and vice-versa. Options:
   - Add a `device_tokens.environment` column (`sandbox`/`production`) stamped by iOS from the build's `aps-environment`, and route each token to the matching APNs host; **or**
   - Try prod host, and on `BadEnvironmentKeyInToken` retry sandbox. The column is cleaner.

3. **Secrets** (Edge Function env): `APNS_AUTH_KEY` (.p8 contents), `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`. Store in Supabase function secrets, never in the repo.

> Alternative if you'd rather keep it in Nitro: a `server/utils/pushService.ts` sender + call it right after each `notifications` insert. Rejected as the primary path — it re-introduces the "every writer must remember to call it" failure mode the webhook avoids, and Nitro on Vercel makes outbound HTTP/2 + .p8 signing more awkward than a Deno edge function.

---

## iOS tasks (smaller — mostly verification)

1. **Stamp token environment.** Add `environment` (sandbox/production, from `aps-environment`) to the `device_tokens` upsert so the sender can route hosts. (Coordinated with the column above.)
2. **Confirm payload-tap handling** routes via `NotificationDestinationParser` to the right screen (inbound → player inbox / notifications). `AppDelegate` shows register handlers but confirm `userNotificationCenter(_:didReceive:)` (tap) and `willPresent` (foreground) are implemented.
3. **Entitlement / provisioning for prod:** `aps-environment` is `development`. Confirm the distribution/TestFlight export flips it to `production` and the App ID has Push enabled. (Archive note says it auto-flips at distribution export — verify, don't assume.)
4. **Badge count:** decide source of truth for `aps.badge` (unread `notifications` count) — server computes and sends it.

---

## Test plan

- [ ] Edge function unit: given a notification row + N tokens, issues N APNs requests with correct topic/payload; prunes on 410.
- [ ] Live: create a `notifications` row (submit a Contact on a public profile) → push arrives on a registered device.
- [ ] Sandbox + production build each receive push (validates host routing).
- [ ] Tap push → app deep-links to the right screen.
- [ ] Dead token (uninstalled app) → row pruned after 410.

---

## Open questions for Chris — ANSWERED 2026-08-27

1. **APNs auth key** — confirmed 2026-08-27: **Key ID `L98FTAU4MP`**, **Team ID `G374A783RH`**. The `.p8` file content itself (private key) is NOT captured here — it's a secret; pull it from the Apple Developer portal (Certificates, IDs & Profiles → Keys) and load it directly into Supabase function secrets as `APNS_AUTH_KEY`, never into the repo or a doc.
2. **Delivery scope** — DECIDED: all notification types. Per-user prefs gate at the type level (see #4), so no allowlist needed in the edge function.
3. **Environment column** — Chris: "if we need it, add environment." Given sandbox-vs-prod host mismatch is a near-certain failure mode (10 registered tokens are all sandbox), **add `device_tokens.environment`** (sandbox/production, stamped by iOS from `aps-environment` at registration).
4. **Push preferences — MUST honor.** Chris: "we have toggles for push notifications, let's honor the user's choices." **Already have the schema** — no new table needed:
   - `notification_preferences` table (`user_id`, `notification_type`, `push_enabled`, `email_enabled`), unique `(user_id, notification_type)`.
   - `notification_type` CHECK values: `follow_up_reminder`, `deadline_alert`, `weekly_digest`, `inbound_interaction`, `offer`, `event`.
   - iOS `PushPreferencesServiceImpl.swift` (Features/Preferences/Services/) already reads/writes `notification_type` + `push_enabled`; UI in `NotificationPreferencesView.swift` (Features/Preferences/Views/) has a per-type toggle for all 6 types.
   - Web's `NotificationType` union only surfaces 4 of the 6 in its own UI (no `inbound_interaction`/`offer` toggle web-side; DB still permits them) — not a blocker, edge function reads the DB row regardless of which platform's UI wrote it.
   - **Edge-function requirement:** before sending, look up `notification_preferences` for `(user_id, notification_type)` matching the new `notifications` row's type; skip the push if `push_enabled = false` (default `true` if no row exists for that type).

---

## Not in scope / already fixed this session

- Public-profile **Contact/Interest 403** (Turnstile CSP) — fixed, live (#512/#513).
- **Inbox 401** (bare `$fetch`) — fixed, live (#516).
- **Header bell empty** (Header never passed the prop) — fixed, promoted (#520/#521).

These are the *in-app* notification surfaces. This handoff is strictly the **device push delivery** gap.
