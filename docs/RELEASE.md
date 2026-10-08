# Releasing The Recruiting Compass (iOS)

How an app update goes from `main` to users, and the systems that keep old versions in check.
Plan/rationale: `planning/2026-09-28-release-infrastructure-plan.md`.

**Don't want to read all this?** Run `/release` in Claude Code. It checks where the current release stands
(`node scripts/release/release-status.mjs`: git + App Store Connect + Xcode Cloud) and walks you through the one
next step.

```
PR → main ──(Xcode Cloud "Default")──▶ build N in TestFlight
                                            │  test on device
bump_version → release notes → prepare_release → submit_release build:N
                                            │  App Review (~24h)
                                   phased release 7 days → tag vX.Y.Z
```

## Version numbers

- **Format:** `MAJOR.MINOR.PATCH` in `MARKETING_VERSION` (the pbxproj). Numbers only — the update gate
  parses it (`AppInfoTests.test_currentVersionParses` fails the build otherwise).
  - `PATCH` (1.0.**1**): bug fixes only.
  - `MINOR` (1.**1**.0): new features, anything users would notice.
  - `MAJOR` (**2**.0.0): big redesigns / breaking changes. Rare.
- **Build number:** assigned by Xcode Cloud; never edit `CURRENT_PROJECT_VERSION`. It must only go up —
  if you ever upload a local archive, bump Xcode Cloud's "Next Build Number" above it.
- **`main` always carries the *next* version.** The moment a version is approved, bump `main`:
  App Store Connect rejects uploads for a version that is already live, so every Xcode Cloud build would
  fail until you do.

```bash
fastlane bump_version type:patch   # or minor / major — edits every configuration
```

## Release checklist

Copy into the release PR description.

- [ ] `main` is green (GitHub Actions `ci.yml`) and the TestFlight build was smoke-tested on a device.
- [ ] `MARKETING_VERSION` is the version you are shipping (`fastlane bump_version` if not).
- [ ] What's New drafted from what merged since the last tag — ask Claude "write the what's new" (the `whats-new`
      skill runs `scripts/release/changes-since-release.sh` and drafts both of these for you to edit):
  - `fastlane/metadata/en-US/release_notes.txt` — user-facing "What's New" (plain language, no ticket numbers).
  - `WhatsNewCatalog` entry **if** the release has a feature users should go try (skip for fixes-only releases).
- [ ] Privacy: if an SDK or analytics event changed, `PrivacyInfo.xcprivacy` **and** the App Privacy
      label in App Store Connect both updated.
- [ ] Screenshots: re-shot only if the UI in them changed (`planning/app-store/`, `fastlane push_screenshots`).
- [ ] Backend: every server change this build depends on is **already deployed to prod** (see
      "Backend compatibility").
- [ ] `fastlane prepare_release` → creates the App Store version, uploads notes, enables phased release.
- [ ] `fastlane submit_release build:<N>` → attaches the Xcode Cloud build and submits.
- [ ] After approval: watch crashes for 48h (Sentry / Xcode Organizer) before phased release passes ~20%.
- [ ] Tag the commit the build came from: `git tag vX.Y.Z <sha> && git push origin vX.Y.Z`
      (sha = the Xcode Cloud build's commit, shown in App Store Connect → Xcode Cloud → Builds).
- [ ] `fastlane bump_version type:patch` on a branch → PR → merge, so `main` is on the next version.
- [ ] Raise `ios_recommended_version` to the new version once it is 100% rolled out (see below).

`prepare_release` / `submit_release` touch production App Store Connect, so run them yourself
(`! fastlane prepare_release`), not from an automated session.

## Hotfixes

- **`main` has nothing unreleased:** fix on a branch → merge → normal release as a PATCH.
- **`main` has unreleased work you don't want to ship:** branch from the release tag instead:
  ```bash
  git switch -c hotfix/1.0.2 v1.0.1
  # fix, bump MARKETING_VERSION to 1.0.2, push; run the Xcode Cloud workflow manually on this branch
  ```
  Submit that build and tag it. Then bring the fix to `main` by **cherry-picking the fix commit(s) only**
  (`git cherry-pick <sha>` on a branch → PR) — never merge the hotfix branch, or its older
  `MARKETING_VERSION` conflicts with `main`'s. If `main` was already on the hotfix's version (e.g. both 1.0.2),
  run `fastlane bump_version type:patch` on `main` too, since that version is now taken.
- **Critical bug in review/live:** App Store Connect → *Contact Us* → **Request Expedited Review**
  (use sparingly — for crashes/data loss, not polish). Meanwhile pause the phased release.
- **A feature is broken but the app works:** flip its PostHog kill switch (below) — no review needed.

## Update gate (retiring old versions)

`public.app_config` (Supabase, prod) holds two thresholds, read by the app via `get_ios_version_policy()`
on launch and when returning to foreground (at most hourly):

| Column | Effect on older versions |
|---|---|
| `ios_recommended_version` | One-time "Update Available" alert per version (dismissible). |
| `ios_minimum_version` | Full-screen **Update Required** — app is unusable until updated. |

```sql
-- Nudge everyone below 1.1.0 once
update public.app_config set ios_recommended_version = '1.1.0', updated_at = now() where id;
-- Hard-block anything older than 1.0.1 (e.g. it calls an API you are removing)
update public.app_config set ios_minimum_version = '1.0.1', updated_at = now() where id;
-- Undo
update public.app_config set ios_minimum_version = null where id;
```

Rules:
- The app **fails open** — if the check can't reach Supabase, nobody is blocked.
- Only raise `ios_minimum_version` to a version that has been **100% released for a few days**, and never
  above what is actually in the App Store (users would be blocked with nothing to update to).
- Version 1.0 has no gate — it can never be forced off. Everything from 1.0.1 on can.
- Malformed values are ignored by the app and rejected by a CHECK constraint.

## Backend compatibility (web + Supabase)

The web app deploys continuously; iOS users update days to months later. Every server change must keep
**all versions ≥ `ios_minimum_version`** working:

- **Expand, then contract.** Add columns/endpoints/fields first; remove or rename only after the gate has
  moved past every app version that reads them.
- New request fields must be optional server-side; new response fields must be ignorable (Swift
  `Decodable` ignores unknown keys — but never make an existing key nullable or change its type).
- Deploy the server change **before** submitting the iOS build that needs it.
- Every Supabase and web-API request carries `X-Client-Platform: ios`, `X-Client-Version`,
  `X-Client-Build` — use them in logs to see which versions still hit an endpoint before removing it.

## Telling users what changed

- **App Store "What's New":** `fastlane/metadata/en-US/release_notes.txt`, uploaded by `prepare_release`.
- **In-app What's New:** add a `WhatsNewRelease` to `WhatsNewCatalog` (`Features/AppUpdate/Models/WhatsNew.swift`).
  Shown once, after the first launch of that version, to users upgrading from an earlier version (never on
  fresh installs). Keep it to 1–4 highlights that match the release notes.
- **Version shown in the app:** Settings → About → Version `X.Y.Z (build)`. Ask users for it in support.

## Kill switches

`app_config.ios_disabled_features` (`text[]`, default `'{}'`) switches individual features off in live builds
without an App Store release. The app reads it via `get_ios_disabled_features()` on launch and when returning
to foreground (every foreground refreshes).
A feature is **on unless its key is listed**. The app fails open: a missing RPC, an error or being offline
leaves everything on, and keys a build doesn't recognise are ignored.

| Key | Entry points hidden when listed |
|---|---|
| `inbound_drafts` | Settings "Review Forwarded Coach Emails" section, More-menu and sidebar "Coach Emails", and push-notification taps for new drafts (land on the default tab) |
| `guardian_claim` | The guardian-claim deep link (`/guardian/claim/<token>`) no longer opens the claim sheet |
| `family_invites` | "Invite by Email" cards in Family Management, the dashboard parent-invite banner, the invite deep link |
| `athlete_messages` | All coach outreach actions: email, text and Instagram on coach cards, the coach detail menu and rail, the dashboard follow-up widget, and the Quick Communication menu items. No `mailto:`/`sms:` fallback, so the guardian lock and send guardrails can't be bypassed. Call and the Twitter profile link stay. |

```sql
-- Switch a feature off
update public.app_config set ios_disabled_features = array_append(ios_disabled_features, 'family_invites'),
  updated_at = now() where id and not ('family_invites' = any(ios_disabled_features));
-- Switch it back on
update public.app_config set ios_disabled_features = array_remove(ios_disabled_features, 'family_invites'),
  updated_at = now() where id;
-- Everything back on
update public.app_config set ios_disabled_features = '{}', updated_at = now() where id;
```

Rules:
- **Keys are permanent once shipped.** Builds in the wild only know the keys they were built with; never rename
  or reuse a key. Add new ones to `FeatureKey` (`Features/FeatureFlags/Models/FeatureKey.swift`) and this table.
- A switch hides entry points only. It never deletes data and never interrupts a flow already on screen.
- A failed refresh keeps the last known state, so a flaky network won't re-enable a feature you killed.
- Changes reach a running app on its next launch or foreground.

## Analytics-driven flags (PostHog)

For risky features, gate the entry point on a PostHog flag so it can be turned off without an app review:

```swift
guard PostHogSDK.shared.isFeatureEnabled("new-timeline") else { return legacyView }
```

Create the flag in PostHog (rollout 100%) before release; set it to 0% to kill the feature. Default the
code path to the **safe/legacy** behavior when the flag is unknown (offline, analytics opted out).
Remove the flag and dead branch a release or two later.

## Crash & health monitoring

- **Sentry** (after the Sentry PR lands): new issues per release, crash-free sessions. Check daily during
  phased release.
- **Xcode Organizer → Crashes / Energy / Hangs:** slower (1–2 days) but covers every opted-in user.
- **TestFlight feedback:** screenshots + comments from testers land in App Store Connect → TestFlight.

## Xcode Cloud

- Workflow **Default**: every push to `main` → Archive → App Store Connect/TestFlight (release Xcode, not
  the local beta). Environment secrets documented in `TheRecruitingCompass/ci_scripts/ci_post_clone.sh`.
- Hotfix branches: start the workflow manually on the branch (Xcode → Integrate → Start Build).
- Add internal testers to the TestFlight group with **automatic distribution** so every `main` build lands
  on your phone.
