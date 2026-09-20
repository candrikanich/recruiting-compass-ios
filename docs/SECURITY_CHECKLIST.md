# Pre-Launch Security Checklist

Cross-platform (iOS + web) pre-launch security audit, run before every public
launch/major release. Last audited: 2026-09-20.

Audits are read-only investigations by Claude Code subagents — findings should
be spot-checked, not treated as ground truth, especially anything marked
NEEDS-HUMAN-VERIFICATION.

## How to re-run

1. Ask Claude to audit iOS (`recruiting-compass-ios`) and web
   (`recruiting-compass-web`) in parallel against the items below.
2. File a GitHub issue per repo for each confirmed FAIL.
3. Update this table with the date and issue links.

## Results — 2026-09-20

| # | Item | iOS | Web |
|---|---|---|---|
| 1 | Secure API keys / no hardcoded secrets | PASS | PASS |
| 2 | `.env` files hidden | PASS | PASS |
| 3 | No hardcoded secrets in source | PASS (see note) | PASS |
| 4 | Authentication required | PASS | PASS |
| 5 | Permissions verified server-side, no trusted client user IDs | PASS | PASS |
| 6 | User data isolation / RLS | NEEDS-VERIFICATION → root cause confirmed, see [#912](https://github.com/candrikanich/recruiting-compass-web/issues/912) | **FAIL** — [#912](https://github.com/candrikanich/recruiting-compass-web/issues/912) |
| 7 | Admin routes protected | PASS (N/A, no admin UI) | PASS |
| 8 | Production debug mode disabled | PASS | PASS |
| 9 | Detailed errors hidden from users | minor gaps, [#180](https://github.com/candrikanich/recruiting-compass-ios/issues/180) | PASS, 1 item folded into [#914](https://github.com/candrikanich/recruiting-compass-web/issues/914) |
| 10 | Input validation server-side | PASS (spot-checked) | **FAIL** — [#913](https://github.com/candrikanich/recruiting-compass-web/issues/913) |
| 11 | Sanitize user content | N/A (native UI) | PASS |
| 12 | File uploads secured | PASS | PASS |
| 13 | SQL/NoSQL injection | N/A (no raw SQL) | PASS |
| 14 | Rate limiting on login/signup | informational FAIL (client-side only), [#181](https://github.com/candrikanich/recruiting-compass-ios/issues/181) — server-side already enforces this | PASS |
| 15 | Git history for secrets | PASS, historical anon-key commits noted (not urgent, anon keys are public-by-design) | PASS |
| 16 | Security headers / CORS | N/A (native) | PASS, verification item folded into [#914](https://github.com/candrikanich/recruiting-compass-web/issues/914) |
| 17 | Keychain / session storage (iOS-specific) | PASS | — |

## Confirmed issues filed

- **[web #912](https://github.com/candrikanich/recruiting-compass-web/issues/912)** — P0. RLS bypassed on 114/117 Supabase-touching API routes via service-role client. This is the root cause behind item #6 for both platforms — iOS's own direct Supabase queries rely on the same RLS policies.
- **[web #913](https://github.com/candrikanich/recruiting-compass-web/issues/913)** — Only 16% Zod coverage across API routes; unauthenticated/high-exposure routes (signup, signup-minor, inbound-email webhook) have no schema validation.
- **[web #914](https://github.com/candrikanich/recruiting-compass-web/issues/914)** — Verification bundle: prod error handler default behavior, single-instance rate-limit store, no explicit CORS allowlist for iOS API consumers.
- **[iOS #180](https://github.com/candrikanich/recruiting-compass-ios/issues/180)** — Two raw system error strings shown to users instead of friendly app-defined messages.
- **[iOS #181](https://github.com/candrikanich/recruiting-compass-ios/issues/181)** — No client-side throttle on login/signup (informational — server already rate-limits).

## Known non-blocking notes

- iOS git history has two real Supabase **anon** keys committed pre-placeholder-stub conversion. Anon keys are designed to be public/client-embedded (RLS is the real gate) — not treated as an incident, but worth rotating opportunistically since it's cheap in Supabase.
- Prior session memory claimed PR #595 was an open "grant-lockdown" follow-up covering this RLS gap — verified during this audit that #595 is **merged** and scoped narrowly to entitlement function grants, not the broader service-role pattern. Memory was stale; corrected here.
