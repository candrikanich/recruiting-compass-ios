# Configuration and Deployment

This document describes environment configuration and where to set it for development vs release. See also [CLAUDE.md](../CLAUDE.md) for quick start and architecture.

---

## Environment Variables

### Required for all runs

| Variable | Description | Where to set |
|----------|-------------|--------------|
| `SUPABASE_URL` | Supabase project URL (e.g. `https://your-project.supabase.co`) | Scheme → Run → Arguments → Environment Variables |
| `SUPABASE_ANON_KEY` | Supabase anonymous (public) key | Same as above |

- **Debug:** If either is missing or set to the placeholder values, the app logs a warning and uses placeholders so previews and tests can run. Do not rely on placeholders for real auth or data.
- **Release / Archive:** Both must be set to real values. If missing or placeholder, the app calls `fatalError` at launch. Configure the same variables in your **Release** scheme (or in CI secrets) so production and Archive builds never use placeholders.

### CI and release runbooks

- When building for TestFlight or App Store, ensure the **Release** scheme has `SUPABASE_URL` and `SUPABASE_ANON_KEY` set (e.g. via Xcode Scheme → Run → Environment Variables, or by exporting them in the CI script).
- Never commit real credentials. Use CI secrets or a local user scheme (uncheck “Shared” so the scheme is not in git).

---

## Keychain Keys

Session and other secure data are stored with `KeychainHelper`. The service identifier is fixed in code; the **account** (key) identifies the item.

| Key (account) | Used for | Set by |
|----------------|----------|--------|
| `savedSession` | Auth session (tokens, user) | `AuthManager` |

- **Service:** `KeychainHelper` uses the app’s bundle identifier–derived service (e.g. `com.chrisandrikanich.TheRecruitingCompass`). If you change the app’s bundle ID or team, existing Keychain entries may not be found; document any migration if you need to preserve sessions across identifier changes.

---

## References

- [CLAUDE.md](../CLAUDE.md) — Setup steps, architecture, testing
- [README.md](../README.md) — Quick start
- [docs/CODE_PATTERNS.md](CODE_PATTERNS.md) — Keychain usage examples, security checklist
