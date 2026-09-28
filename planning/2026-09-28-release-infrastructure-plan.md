# Release Infrastructure Plan — post-1.0 versioning & updates

**Date:** 2026-09-28 · **Status:** approved by Chris ("lets go with your recommendation"), implementing
**Context:** 1.0 (build 32) is WAITING_FOR_REVIEW. There is no mechanism yet to retire old app versions,
tell users about updates, see crashes, or cut repeatable releases. Solo dev, first app — optimize for
low ceremony and safety.

## Goals

1. Old app versions can be retired without breaking users silently (hard gate) and nudged (soft prompt).
2. Users can see what changed (in-app What's New) and which version they run (About screen).
3. Server can tell which app version is calling (request headers).
4. Crashes are visible within minutes, not days (Sentry).
5. Every release follows the same short checklist; version numbers follow one convention.

## Current state (verified 2026-09-28)

- `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` (Xcode Cloud overrides the build number).
- Xcode Cloud workflow "Default": every push to `main` → Archive (App Store eligible). No tag/PR workflows.
- fastlane lanes: pull/push metadata + screenshots. `release_notes.txt` empty.
- No git tags. No crash reporter. No version shown in the app. No min-version check.
- `public.app_config` single-row table exists (web repo migration `20260916000000`), SELECT for
  `authenticated` only. App Store app ID = `6758562332`.

## Design

### A. Version policy (web repo migration)

- Add to `app_config`: `ios_minimum_version text`, `ios_recommended_version text` (nullable; NULL = no gate),
  CHECK `^\d+(\.\d+){0,2}$`.
- `public.get_ios_version_policy()` — `SECURITY DEFINER`, `STABLE`, returns just those two columns,
  `GRANT EXECUTE` to `anon, authenticated`. RPC instead of widening table SELECT so logged-out users
  (who can hit a broken signup) are covered without exposing pricing columns to anon.
- Operating it = one SQL `UPDATE` in the Supabase dashboard; no deploy.

### B. iOS update gate (`Features/AppUpdate/`)

- `AppVersion` — Comparable semver-ish value (`1`, `1.0`, `1.0.1`; missing parts = 0).
- `AppUpdateStatus.evaluate(current:policy:)` — pure: `.updateRequired` if current < minimum,
  else `.updateAvailable` if current < recommended, else `.upToDate`. Unparseable values ignored.
- `AppVersionPolicyService` (protocol + Supabase impl) calls the RPC.
- `AppUpdateManager` (`@Observable @MainActor`): checks on launch + foreground (throttled 1h).
  **Fails open** — a fetch error never blocks the user. Soft prompt shown once per recommended version.
- `UpdateRequiredView` — full-screen blocking overlay (above auth/landing) with "Update Now" →
  App Store. Soft prompt = alert with "Update" / "Not Now".

### C. What's New

- `WhatsNewCatalog` — in-code list of releases with user-facing bullet points.
- Rule: record last-seen version; fresh installs (nil) record silently; upgrades show the entry for the
  current version if one exists; always record afterwards. Shown only on the main app (not onboarding).
- 1.0 never recorded a last-seen version, so 1.0→1.0.1 is treated as fresh. Accepted: 1.0.1 is a
  plumbing release; every upgrade after it works.

### D. Version visibility + headers

- `AppInfo` — `version`, `build`, `displayVersion` ("1.0.1 (33)"), App Store URL, client headers.
- About screen footer shows "Version 1.0.1 (33)".
- Headers `X-Client-Platform: ios`, `X-Client-Version`, `X-Client-Build` on Supabase client (global
  headers) and on every web-API `URLRequest`. Server-side use is future work (logging / rejection).

### E. Crash reporting (separate PR)

- `sentry-cocoa` via SPM, DSN via `SENTRY_DSN` build setting → generated config (empty = disabled, so
  local/debug builds stay quiet). Release = `CFBundleShortVersionString`, dist = build number.
- dSYM upload from Xcode Cloud `ci_post_xcodebuild.sh` (needs `SENTRY_AUTH_TOKEN` secret).
- Privacy: `PrivacyInfo.xcprivacy` gains Crash Data + Performance Data (not linked, not tracking);
  **App Privacy label in App Store Connect must be updated by Chris before the next submission.**

### F. Release process (docs + fastlane)

- `docs/RELEASE.md`: version convention, per-release checklist, hotfix path, backend-compat rules,
  how to operate the version gate, feature-flag kill switches (PostHog), phased release.
- fastlane `bump_version type:patch|minor|major` (edits MARKETING_VERSION in pbxproj).
- Tag `v1.0.0` at `068782e9` (build 32).
- Xcode Cloud: keep "Default" (main → TestFlight). Releases = pick a main build, submit, tag.

## PR breakdown

1. iOS `chore/release-infra`: B, C, D, F (docs, fastlane, plan).
2. web: A (migration). Must be applied to prod before the gate has any effect; iOS fails open until then.
3. iOS: E (Sentry) — blocked on a Sentry iOS project + DSN.

## Order of operations after merge

1. Apply web migration to prod.
2. When 1.0 is approved: `fastlane bump_version type:patch` → 1.0.1 on main immediately (uploads with
   a closed 1.0 train get rejected).
3. Ship 1.0.1 (gate + headers + Sentry). From then on every version is retirable.

## Unresolved questions

- None blocking. Sentry project creation + App Privacy label update are Chris's actions.
