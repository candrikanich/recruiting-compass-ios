---
name: release
description: Walk Chris through shipping an iOS app update, one step at a time — figures out where the current release stands (git, App Store Connect review state, phased rollout, Xcode Cloud builds), does the safe parts itself, and tells him exactly what to run for the rest. Use for /release, and whenever he asks "where are we with the release", "what's next for 1.0.1", "is the update approved", "can I submit", "how's the rollout going", "ship the next version", or is anywhere in docs/RELEASE.md — even mid-conversation.
---

# /release — guided iOS release

Chris is a solo developer shipping his first app and is still learning the release process. This skill's job is to
make each release feel like following a GPS: **say where he is, say the one next thing, do what you safely can,
and explain the why in a sentence** so the process sticks. The full runbook is `docs/RELEASE.md`; don't re-explain
all of it — just the step he's on.

## 1. Find out where things stand

```bash
node scripts/release/release-status.mjs
```

Read-only. It pulls `origin/main` (version, tags, commits since the last tag, whether release notes were written for
this release), App Store Connect (every recent version's state, attached build, phased-release day) and Xcode Cloud
(latest builds and the commits they came from), then prints a **Stage** and a **Next** line.

Trust the stage — its logic is tested (`node --test scripts/release/release-status.test.mjs`). If the report shows
something the stage didn't account for (e.g. an error line), say so rather than guessing.

## 2. Act on the stage

Lead your reply with the stage in plain words ("1.0 is in review — nothing to do yet") and the next step. Then:

| Stage | What you do | What Chris does |
|---|---|---|
| `in-review` | Nothing. Mention merges can continue but the version must not be bumped until approval (a rejection would need another build of the same version). | Wait. |
| `rejected` | Help read and fix the rejection; if code changed, it ships as a new build of the same version. | Paste Apple's message; resubmit after the fix. |
| `approved-held` | Explain Apple approved it but is holding release until the matching iOS version ships (it goes out automatically). Tag + bump are safe now, same as `released`. | Nothing; wait for Apple's OS release. |
| `released` | Walk the post-release list in the Next line, in order. You may create the version tag **after he confirms** the commit (`git tag vX.Y.Z <sha> && git push origin vX.Y.Z` — the sha is the commit of the build that was approved; the status report lists build → commit). You may open the bump PR (`fastlane bump_version type:patch` on a branch). | Release it in App Store Connect if pending; watch the rollout. |
| `needs-bump` | Open the bump PR: branch, `fastlane bump_version type:patch` (minor if features are already merged), commit `chore: bump version to X.Y.Z`, PR. | Merge it. |
| `nothing-to-release` | Say so. | Keep building. |
| `draft-notes` | Invoke the **whats-new** skill, then open a PR with its output. | Edit/approve the wording, merge. |
| `waiting-for-build` / `build-failed` | Report the build; for failures, fetch the logs if asked (App Store Connect → Xcode Cloud, or the ASC API). | Wait / decide on a fix. |
| `ready-to-prepare` | Remind him to smoke-test that exact build from TestFlight first. | `! fastlane prepare_release` |
| `ready-to-submit` | Give the exact command with the build number from the Next line. | `! fastlane submit_release build:N` |

When the Next line ends with **"Also: X.Y.Z rollout: …"**, the previous version is still rolling out while main has
moved on — mention it every time until it completes; that's the version users are actually getting. If it reports a
tag pointing at the wrong commit, show both shas and ask before moving the tag (`git tag -f` + force-push of a tag).

After a release reaches 100% (phased release `COMPLETE`), also offer the optional nudge for people on older versions:
`update public.app_config set ios_recommended_version = 'X.Y.Z', updated_at = now() where id;` in the Supabase SQL
editor (prod). Only suggest `ios_minimum_version` (a hard block) when an old version is actually broken — see
docs/RELEASE.md "Update gate".

## Boundaries

- **Never run anything that changes the live App Store listing or production data** — `prepare_release`,
  `submit_release`, `push_metadata`, `push_screenshots`, SQL against prod. Chris runs those himself with the `!`
  prefix so they happen in his terminal, on purpose. Give him the exact command.
- Everything that goes to `main` goes through a branch and PR (version bumps, notes).
- Tags are outward-facing and permanent-ish: confirm the version and commit with him before pushing one.

## Teaching as you go

He'll get the hang of it over a few versions. Per step, add one short line on *why* when it isn't obvious — e.g.
"bump now, because App Store Connect rejects new uploads for a version that's already live", or "phased release
means only ~1% of users get it on day 1, so a bad crash stays small". Skip the explanations he's clearly already
absorbed in the conversation.

If he asks about something outside the current stage (hotfixes, expedited review, kill switches, backend
compatibility), answer from docs/RELEASE.md's matching section rather than improvising.
