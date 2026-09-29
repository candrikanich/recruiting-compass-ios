---
name: whats-new
description: Draft an iOS release's user-facing "What's New" from what actually merged since the last release — writes the App Store release notes (fastlane/metadata/en-US/release_notes.txt) and, when warranted, the in-app WhatsNewCatalog entry. Use whenever preparing an App Store update or TestFlight release, or when the user says "what's new", "release notes", "what changed since the last version", "prep 1.0.1 / 1.1", "write the update notes", "draft the App Store notes", or is walking through docs/RELEASE.md step 4 — even if they don't name the files.
---

# What's New — release notes from merged changes

Turns everything merged to `main` since the last release tag into two user-facing artifacts:

1. **App Store "What's New"** → `fastlane/metadata/en-US/release_notes.txt` (uploaded by `fastlane prepare_release`; required for every update).
2. **In-app What's New sheet** → an entry in `WhatsNewCatalog.releases`
   (`TheRecruitingCompass/TheRecruitingCompass/Features/AppUpdate/Models/WhatsNew.swift`), shown once to users who upgrade.
   Optional — only when there's a feature worth interrupting someone for.

Both are read by high-school athletes and their parents, not developers. That audience is the whole point of this skill:
the raw material is written for code review, and the output has to make sense to a parent on their phone.

## Workflow

### 1. Gather what shipped

```bash
scripts/release/changes-since-release.sh                        # newest v* tag → origin/main
scripts/release/changes-since-release.sh v1.0.1                 # a specific tag → origin/main
scripts/release/changes-since-release.sh v1.0.1 hotfix/1.0.2    # hotfix: tag → the hotfix branch
```

The range must end at whatever the release build is made from. For a normal release that's `main`; for a hotfix
built from a release tag it's the hotfix branch — ending at `main` would advertise unreleased work to users.

It prints the version being prepared (`MARKETING_VERSION` at the end ref) and, for every commit in the range, the PR
title plus its full description (quoted). If a PR description can't be fetched it says so and falls back to the
commit body — treat those entries with extra care when classifying. Read the descriptions, not just the titles — a `fix:` title often hides a visible
behavior change, and a `feat:` can be purely internal.

**Check the version first.** If `MARKETING_VERSION` still equals the last tag's version (e.g. tag `v1.0.0`, version
`1.0`), `main` hasn't been bumped and these notes would land on an already-released version. Stop and tell the user to
run `fastlane bump_version type:patch` (or `minor` if the changes include new features) — see docs/RELEASE.md.

### 2. Sort every change into one of three buckets

| Bucket | What goes here | Examples |
|---|---|---|
| **New / improved** | Something a user can see or do that they couldn't before, or that now works noticeably better | new screen, new filter, faster load of a list they use, clearer wording |
| **Fixed** | A bug a user could have hit | wrong date shown, crash on save, invite link not working |
| **Internal** — leave out | Anything a user can't perceive | `ci:`, `chore:`, `docs:`, `test:`, `refactor:`, dependency bumps, build scripts, telemetry, crash reporting, analytics, privacy-manifest edits, request headers, code moves |

When unsure whether something is visible, ask: *would a parent notice if we reverted it?* If no, it's internal.
Security/privacy fixes that users can't perceive stay internal — don't advertise vulnerabilities in release notes.

### 3. Write `release_notes.txt`

Replace the file's contents (it describes one version at a time — never append to the previous release's notes).

- Plain language, second person ("You can now…"), no PR numbers, ticket IDs, code names, or tech terms
  (Supabase, API, cache, SwiftUI…).
- Lead with the most useful change. One line per item, `•` bullets, fixes after features.
- Group trivial fixes into one line ("Fixes for a few display issues on the Schools list.").
- Keep it short — most people read two lines. Hard App Store limit is 4000 characters; aim for under 600.
- **Nothing user-visible?** Use exactly one line: `Bug fixes and performance improvements.` Don't invent features.

Example (for a release with one feature and two fixes):

```
You can now filter your Schools list by division.

• Filter Schools by D1, D2, D3, NAIA or JUCO from the new filter button.
• Fixed deadlines sometimes showing a day early.
• Fixed the invite link not opening the app on some iPhones.
```

### 4. Decide on an in-app What's New entry

Add one **only if the release has at least one "New / improved" item a user would want to go try**. Fixes-only
releases upgrade silently — interrupting someone to tell them a bug they never saw is gone is noise.

If warranted, add to `WhatsNewCatalog.releases` in `WhatsNew.swift` (one entry per version; replace an existing entry
for the same version rather than adding a second):

```swift
static let releases: [WhatsNewRelease] = [
  WhatsNewRelease(
    version: AppVersion(major: 1, minor: 1, patch: 0),
    highlights: [
      WhatsNewHighlight(
        systemImage: "line.3.horizontal.decrease.circle",
        title: "Filter by Division",
        detail: "Narrow your Schools list to D1, D2, D3, NAIA or JUCO."
      )
    ]
  )
]
```

- `version` must equal `MARKETING_VERSION` exactly (1.1 → `major: 1, minor: 1, patch: 0`) — the sheet only shows when
  the running version matches.
- 1–3 highlights (4 max), features only. Title ≤ 4 words, detail one sentence.
- `systemImage` is an SF Symbol name. Use common, long-standing symbols (e.g. `calendar`, `bell.badge`,
  `person.2`, `chart.bar`, `magnifyingglass`, `doc.text`, `star`, `sparkles`); an invalid name renders blank.
- Every highlight must also appear in `release_notes.txt` — the two should never disagree.
- Keep older entries in the list; they're harmless and document history.

### 5. Show the draft, then verify

Show the user the notes and the Swift entry (if any) along with which changes you left out as internal, so they can
move something between buckets. They know what users actually noticed; the PR descriptions don't.

After writing the files:
- `wc -c fastlane/metadata/en-US/release_notes.txt` — under 4000.
- If `WhatsNew.swift` changed, build to confirm it compiles (see CLAUDE.md for the `xcodebuild` command; pick a
  simulator by id from `xcrun simctl list devices available`).
- Commit on a branch and open a PR (`docs(release): notes for X.Y.Z`) — `main` takes changes only through PRs.

Next in the runbook (docs/RELEASE.md): the user runs `fastlane prepare_release` to push the notes to App Store Connect.
