# Infrastructure History

## 2026-03-15 — Push notifications (APNs)
End-to-end APNs push: NotificationDestinationParser, PushNotificationManager, per-type prefs, `device_tokens` / `notification_preferences` migrations, and a send-push edge function + trigger.

## 2026-08-08 — Video Links Phase A (DB)
Created canonical `video_links` table (schema, owner/family RLS, max-5 insert trigger, health columns) plus idempotent JSONB backfill via two web Supabase migrations. Applied to live DB 2026-08-09; not recorded in schema_migrations (MCP drift) — verify with `to_regclass`.

## Swift 6 Concurrency Fix — COMPLETE (2026-02-10)
Resolved 50+ Swift 6 strict concurrency warnings across 17 files by removing `nonisolated init` and replacing `@MainActor` singleton default parameters with optional `nil` parameters resolved via `??` inside the init body. Pattern: `init(service: (any ServiceManaging)? = nil) { self.service = service ?? ServiceImpl.shared }`. All ViewModels remain fully testable via protocol-based DI.

## RLS Fix — Family Members (2026)
iOS app was unable to see all family members due to overly restrictive RLS. Fixed by (1) updating `family_members` RLS to allow users to see all members in families they belong to, and (2) splitting the single inner-join query into two separate fetches (family_members then users) to avoid RLS-blocked joins. Migration: `supabase/migrations/20260219120000_fix_rls_recursion_and_family_units.sql`.

## Security Remediation (2026-02-19)
Three fixes applied: (1) Keychain session injected into Supabase client on cold start via `setSession(accessToken:refreshToken:)` to prevent empty-session API failures; (2) Hardcoded Supabase credentials removed from `docs/VISUAL_QA_TESTING_GUIDE.md` — rotate anon key if previously exposed; (3) RLS migration `20260219120000` added to version-control the recursion-safe `family_members` policy using a `user_is_family_member()` SECURITY DEFINER function.

## Architecture Review (2026-02-19)
Overall score 8.2/10. Top recommendations: extend `CacheManaging` to Coach detail and other detail screens; document `nonisolated deinit` pattern (already in CODE_PATTERNS); add `NWPathMonitor` for proactive offline messaging; standardize `handleError`/`withLoading` helpers across ViewModels. Strengths: MVVM consistency, protocol-based DI, accessibility, security.
