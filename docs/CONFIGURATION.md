# Configuration and Deployment

This document describes environment configuration and where to set it for development vs release. See also [CLAUDE.md](../CLAUDE.md) for quick start and architecture.

---

## Environment Variables

### Required for all runs

| Variable | Description | Where to set |
|----------|-------------|--------------|
| `SUPABASE_URL` | Supabase project URL (e.g. `https://your-project.supabase.co`) | **Debug:** Scheme → Run → Arguments → Environment Variables. **Release/TestFlight:** `Release.xcconfig` (see below). |
| `SUPABASE_ANON_KEY` | Supabase anonymous (public) key | Same as above. |

- **Debug:** If either is missing or set to the placeholder values, the app logs a warning and uses placeholders so previews and tests can run. Do not rely on placeholders for real auth or data.
- **Release / Archive / TestFlight:** Scheme environment variables are **not** embedded in the app. Archived builds (TestFlight, App Store) get credentials from **`Release.xcconfig`** only. Edit `TheRecruitingCompass/Release.xcconfig` and replace the placeholder URL and key with your real values before archiving. The values are compiled into the app’s Info.plist so the app can read them at launch.

### TestFlight / App Store (Archive builds)

1. Open **`TheRecruitingCompass/Release.xcconfig`**.
2. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to your real Supabase project URL and anon key (replace the `https://placeholder.supabase.co` and `placeholder-key` values).
3. Create an Archive (Product → Archive). The app will read these values from the bundle at runtime.
4. Do not commit real production keys if you later add `Release.xcconfig` to `.gitignore`; use CI secrets to generate the file or override build settings instead.

### CI and release runbooks

- When building for TestFlight or App Store, credentials must come from **Release.xcconfig** (or from build settings / a generated xcconfig in CI). Scheme → Run → Environment Variables are not available to archived builds.
- Never commit real credentials if you use a secret xcconfig; use CI secrets or a local-only file.

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
