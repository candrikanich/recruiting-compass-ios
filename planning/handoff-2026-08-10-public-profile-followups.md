# Handoff: iOS Public Profile — fast-follows
**Date:** 2026-08-10
**Branch to create:** `fix/public-profile-followups` off `main` (804e050)
**Status:** NOT STARTED — main feature SHIPPED, these are the deferred polish items

## Context
The iOS Public Profile feature shipped to `main` (merge `804e050`, feature commits `70b5d55..f35b9ff`). Full detail in memory `ios-public-profile.md`. This handoff covers only the 4 deferred fast-follows the final review flagged as non-blocking. Do them on a fresh branch off `main`.

**Feature module:** `TheRecruitingCompass/TheRecruitingCompass/Features/PublicProfile/`
**Also touched:** `Features/Coaches/Views/CoachDetailView.swift` (Send Profile), `Features/Preferences/Views/PlayerDetailsView.swift` (5th "Public" segment), `Features/Preferences/ViewModels/PlayerDetailsViewModel.swift` (`publicTargetUserId` accessor).

## Completed This Session
- Full Public Profile feature (14 TDD tasks) — SHIPPED, merged to `main` `804e050`.
- No fast-follow work started yet.

## In Progress (Uncommitted)
- None for the follow-ups.
- NOTE: the main checkout is on branch `feat/multiple-travel-teams` with 3 pre-existing uncommitted files (`Localizable.xcstrings`, `NetworkMonitor.swift`, `SupabaseConfig.generated.swift`) — NOT this work, do NOT touch/commit them. `SupabaseConfig.generated.swift` is a build artifact that regenerates every build and must NEVER be committed.

## The 4 fast-follows (do #1–#3, verify #4)

### 1. Two-tap share → one-tap  [small, do]
`CoachDetailView.swift` "Send Profile" currently: tap button → opens a `.sheet(item:)` containing a `ShareLink` row → tap again for the system sheet. Make it one tap: present a `UIActivityViewController` directly via a small `UIViewControllerRepresentable`, OR bind `ShareLink(item:)` as the button label so the system sheet opens on the first tap. `SendProfileViewModel.shareURL(forCoachId:)` already returns the `URL?`; the async fetch (fetch profile → publish check → create tracking link) must complete before presenting, so keep the "compute URL, then present" flow — a `ShareLink` needs the URL up front, so the representable/activity-controller path is likely cleaner here.

### 2. `playerName` empty on parent-viewing card  [small–med, do]
In `PublicProfileViewModel.assembleCard()`, `playerName` is `""` when viewing a non-self athlete (`targetUserId != authManager.user?.id`) — currently only `authManager.user?.fullName` is used (self only). Reachable when a parent opens the athlete's Player Profile → Public tab. Fix: fetch the target user's `full_name` from the `users` table. Cheapest path: extend the `ProfilePhotoService` users query (it already does `SELECT profile_photo_url FROM users WHERE id = ?`) to also select `full_name`, or add a small name lookup. Then use it for `playerName` when `targetUserId` is set.

### 3. Surface save retry / 5xx errors  [small, do]
`PublicProfileViewModel.save()` silently swallows failures: the `.unauthorized` retry uses `try?` (a retried `slugTaken`/`slugInvalid`/other is dropped) and the final `catch` discards `.notMember`/`.server(5xx)` with a "transient; keep local state" comment. Add a `var saveError: String?` published property, set it in those catch branches with a user-facing message, and show it in `PublicTab.swift` (a small banner/text near the editor, like `slugError` is shown). Clear it at the start of `save()`.

### 4. 5-segment crowding  [verify only, don't pre-fix]
`PlayerDetailsView` now has 5 segmented-Picker tabs (Basics/Athletics/Academics/History/Public). Build + screenshot on a narrow device (iPhone SE-class width) and eyeball whether the segments crowd/truncate. ONLY if it looks bad: switch that segmented Picker to a menu-style or scrollable control. If it looks fine, close with no code change.

## Known Issues / Blockers
- None blocking. (Lower-priority items also noted in memory: `shareURL`/profile refetch-after-save; DRY duplicate slug-validation switch in `save()` — optional, skip unless bored.)

## Test Status (from the shipped feature, on `main`)
- Unit tests: PASS — PublicProfile suite ~35 tests, 0 failures; post-merge integrated run 62/62.
- Build: PASS (whole app).
- Lint: PASS — feature dir 0 SwiftLint violations (repo `line_length` limit is 140, not 120).
- Type-check: n/a (Swift).

## Environment gotchas (IMPORTANT — will bite the next session)
- **Subagents cannot drive `xcodebuild` to completion here** — they background it and yield without converging. Pattern that worked: implementer WRITES + commits (no build); the controller/main session runs the background `xcodebuild test` verify.
- **Multi-class `xcodebuild test` runs exit non-zero at TEARDOWN** (macOS 26 flake) even with 0 failures. Trust the `Test case ... passed`/`failed` counts + `** TEST SUCCEEDED **`, NOT the shell exit code. Grep uses lowercase: `grep -cE "Test case .*passed"`.
- On simulator stall (`RBSRequestErrorDomain` / "No such process"): `xcrun simctl shutdown all && killall -9 CoreSimulatorService`, retry.
- Run builds from `TheRecruitingCompass/` (the Xcode project wrapper). Destination `platform=iOS Simulator,name=iPhone 17`.
- New `.swift` files auto-included (PBXFileSystemSynchronizedRootGroup) — never edit `.xcodeproj`.
- SourceKit cross-file diagnostics ("Cannot find type X in scope", "No such module XCTest/UIKit", "Color has no member Surface/Text") are FALSE POSITIVES — trust `xcodebuild`, not the inline diagnostics.
- If working in a git worktree, copy the gitignored `TheRecruitingCompass/Release.xcconfig` into it or the build fails.

## Resume Command
> Continue the iOS Public Profile fast-follows. Read planning/handoff-2026-08-10-public-profile-followups.md. Create branch `fix/public-profile-followups` off main, then do items #1 (one-tap share), #2 (parent-view playerName), #3 (surface save errors), and run the #4 5-segment crowding screenshot check.

## Next Steps (in order)
1. `git fetch && git checkout main && git pull` (main = 804e050), create `fix/public-profile-followups`.
2. #3 save-error surfacing (smallest, self-contained VM + PublicTab change) + test.
3. #1 one-tap share in CoachDetailView.
4. #2 target-user name lookup in assembleCard + service.
5. #4 build + iPhone SE screenshot; fix Picker only if crowded.
6. Verify each via controller-run background `xcodebuild test` (trust counts, not exit code); then finishing-a-development-branch → PR or merge to main.
