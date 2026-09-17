# Configuration and Deployment

This document describes environment configuration and where to set it for development vs release. See also [CLAUDE.md](../CLAUDE.md) for quick start and architecture.

---

## Environment Variables

### Required for all runs

| Variable | Description | Where to set |
|----------|-------------|--------------|
| `SUPABASE_URL` | Supabase project URL (e.g. `https://your-project.supabase.co`) | **Debug:** Scheme → Run → Arguments → Environment Variables. **Release/TestFlight:** `Release.xcconfig` (see below). |
| `SUPABASE_ANON_KEY` | Supabase anonymous (public) key | Same as above. |
| `API_BASE_URL` | Web app base URL (e.g. `https://your-app.vercel.app`) | Same as above. |

- **Debug:** If any of these are missing or set to the placeholder values, the app logs a warning and uses placeholders so previews and tests can run. Do not rely on placeholders for real auth or data.
- **`API_BASE_URL` is required, not optional, for any DEBUG run that exercises family creation or onboarding.** `createFamily(role:)` always routes through `POST /api/family/create` on the web API — there is no direct-Supabase fallback. A missing `API_BASE_URL` makes family creation throw immediately, which breaks signup/onboarding for both player and parent roles. It's also required for the dashboard Action Items widget (`GET /api/suggestions`, `PATCH .../dismiss`, `PATCH .../complete`); if unset there, the widget just shows "No action items at this time" instead of throwing. Release/TestFlight/App Store builds already have a production `API_BASE_URL` fallback baked in (`SupabaseConfig.swift`), so this only matters for local DEBUG runs from Xcode.
- **Release / Archive / TestFlight:** Scheme environment variables are **not** embedded in the app. Archived builds (TestFlight, App Store) get credentials from **`Release.xcconfig`** only. Edit `TheRecruitingCompass/Release.xcconfig` and replace the placeholder URL, key, and API base URL with your real values before archiving. The values are compiled into the app’s Info.plist so the app can read them at launch.

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

## Universal Links (Invite Deep Linking)

For invitation emails to open the app on iOS when the user taps the link, the web server at [myrecruitingcompass.com](https://www.myrecruitingcompass.com) must host an **apple-app-site-association** file.

### 1. Host `apple-app-site-association`

Serve this file at:

- `https://www.myrecruitingcompass.com/.well-known/apple-app-site-association`
- or `https://www.myrecruitingcompass.com/apple-app-site-association`

**Content** (no file extension; `Content-Type: application/json`):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "G374A783RH.com.chrisandrikanich.TheRecruitingCompass",
        "paths": ["/invite/*", "/join", "/guardian/claim/*"]
      }
    ]
  }
}
```

- **Team ID:** `G374A783RH` (from Xcode)
- **Bundle ID:** `com.chrisandrikanich.TheRecruitingCompass`

### 2. Invite link format

Invitation emails must use links like:

- `https://www.myrecruitingcompass.com/invite/TOKEN`
- or `https://www.myrecruitingcompass.com/join?token=TOKEN`

When the app is installed, iOS opens it instead of Safari. The app presents `InviteJoinView` with the token.

### 3. Verify

- Test on a **physical device** (Universal Links do not work correctly in Simulator)
- Ensure `API_BASE_URL` (or the invite email base URL) uses `https://www.myrecruitingcompass.com`

---

## References

- [CLAUDE.md](../CLAUDE.md) — Setup steps, architecture, testing
- [README.md](../README.md) — Quick start
- [docs/CODE_PATTERNS.md](CODE_PATTERNS.md) — Keychain usage examples, security checklist
