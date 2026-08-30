# CLAUDE.local.md archive — sessions prior to 2026-08-24

Archived out of `CLAUDE.local.md` on 2026-08-26 to keep that file scoped to the
current session only (memory-management rule: archive old, keep current).

---

## Prior session: iOS Public Profile — SHIPPED to main (historical)

**Status:** iOS Public Profile feature SHIPPED to main; 4 fast-follows NOT STARTED (handed off)
**Branch:** feature merged to `main` (804e050, pushed)
**Build:** PASS · **Tests:** PASS (62/62) · **Lint:** PASS · **Handoff:** `planning/handoff-2026-08-10-public-profile-followups.md`

## Session 2026-08-06: full-repo audit + SEC-1..4 remediation — COMPLETE, pushed

Fresh audit on main (post-Phase-6b): SwiftUI standards, security, performance, App Store
readiness. Findings + statuses in `security-scan/plan.md` / `state.json` (all 4 FIXED).
Commit `f30bdaa`, ff-merged to main, **pushed** (origin even at f30bdaa).
Suite: 3726 passed / 0 failed (includes 6 new `COPPAHelperTests`).

**What changed (commit f30bdaa):**
- `SupabaseConfig.generated.swift` → committed placeholder stub restored (real prod anon
  key/URL had been committed over it). Build phase regenerates real values every build →
  **file will always show modified after a build; NEVER commit that diff.**
- `--uitesting` override (`SupabaseConfig.swift`) + AuthManager Keychain session wipe now
  `#if DEBUG` — Release binaries ignore them. E2E unaffected (Debug builds).
- Release builds use new `Config/Info-Release.plist`: NO ATS local-networking exception
  (Debug keeps it for local-Supabase E2E), `ITSAppUsesNonExemptEncryption=NO` (both plists —
  kills the export-compliance questionnaire per upload).
- `COPPAHelper.isUnderAge` fails closed on unparseable DOB + new
  `TheRecruitingCompassTests/Core/Utilities/COPPAHelperTests.swift`.
- `planning/APP_STORE_LAUNCH_CHECKLIST.md` corrected (gitignore claim was false; location
  permission IS requested — `NSLocationWhenInUseUsageDescription` in pbxproj; encryption
  item done; dated 2026-08-06).

**Audit verdict (details in session security-scan/ + memory `audit-2026-08-plan.md`):**
- Code is clean: zero deprecated SwiftUI API (foregroundColor/NavigationView/
  presentationMode/@Published/AnyView/Binding(get:)/try!/as!/print all 0 in app source);
  dark-mode AppColors fully adaptive; Phase 3.3/3.6 perf items verified DONE (cached
  filtered arrays + InMemoryCache in 21 VMs); ActivityRealtimeService now wired
  (RecentActivityWidget:124) — no longer dead code.
- FALSE POSITIVE logged: `MiniBarChart.swift:15` `.cornerRadius(3)` is Swift Charts
  `BarMark.cornerRadius(_:)` (current API) — do NOT "fix".
- SwiftLint: 548 violations (from ~1053), cosmetic (line_length 248, identifier_name 140).

**Still open (process/decisions, not code):**
- iPad: `TARGETED_DEVICE_FAMILY = "1,2"` → either do a real iPad pass + screenshots, or
  ship iPhone-only (`1`) for v1.
- ASC: metadata, privacy nutrition labels (add Location — WhenInUse used for Home Location
  quick-set), screenshots, demo review account.
- `aps-environment = development` in entitlements — auto-flips at distribution export;
  verify in Archive → Validate App.
- Uncommitted in main checkout: `Core/Localizable.xcstrings` mod (pre-existing, not this
  session's), 2 untracked phase-5 handoff docs in `planning/`.
- `planning/2026-08-02-ios-audit-remediation-plan.md` still referenced everywhere, still
  missing — recreate from commit trail or retire references.

**Session gotchas (recorded in memory too):**
- Session started stuck in DELETED worktree `audit-phase0` (stale isolation blocked all
  Bash) — fixed via ExitWorktree. Stale zero-byte `.git/index.lock` also removed.
- `xcodebuild test -quiet` may print NO "** TEST SUCCEEDED **" line — trust xcodebuild's
  own exit code + passed/failed counts; NEVER read success off a grep pipeline's exit.

---

# Archived: phase6b-localization worktree close-out (2026-08-06, merged to main)

## Phase 6b: Text() call-site localization — COMPLETE

Scope: every `Text(...)` call site in `TheRecruitingCompass/TheRecruitingCompass/`
(app source), classified and, where warranted, routed through `String(localized:)`.
Companion to Phase 6a (accessibilityLabel migration, `39c7953`).

**Census baseline (unchanged start-to-finish — see below for why):**
- `literal`: 645 sites — already `LocalizedStringKey`-backed via Swift's native
  `Text(_ key: LocalizedStringKey)` initializer. Zero-touch, unlike 6a's
  `accessibilityLabel` sites which needed explicit wrapping.
- `passthrough`: 431 sites — `Text(someVariable)` where the census can't tell if
  `someVariable` traces back to a literal (needs wrapping) or is genuinely dynamic
  (correctly left alone). All 431 were manually triaged across Tasks 2-7.
- `date-style`: 6 sites — `Date(..., style:/format:)`, no action needed.

**Why the census output is byte-identical pre/post migration:** the fix for a
literal-template passthrough site (e.g. `SomeEnum.displayName`) was applied at the
*definition* site (the `var displayName: String` computed property), not the
`Text(...)` call site — one wrap covers every caller. The census only scans
`Text(` call sites, so it can't see that upstream work; this is expected, not a
gap.

**7 commits, 6 feature batches (Tasks 2-7), full trail in**
`.superpowers/sdd/2026-08-05-localization-text-sites/progress.md`:
1. `31f8c65` Family/Timeline/Legal/Landing/Settings/Profile/Onboarding/About
2. `021c873` CommunicationTemplates/ActivityFeed/Tasks/Notifications/Help/Analytics
3. `09745a7`/`3c4ea20` Interactions/Performance/Offers/Preferences
4. `e2cf81f` Auth/Documents/Coaches/Events/Dashboard (largest batch, 140 sites)
5. `a91a770` Schools (53 sites)
6. `cd699db` Shared/Components (31 sites, final batch)

## Known follow-ups (deliberately out of scope for Phase 6b — not gaps)

- **`FamilyMember.role`** (Dashboard's AthleteRow) — plain `String` used for
  identity comparisons elsewhere in the codebase, not a display-only enum;
  wrapping risks breaking equality checks. Flagged, not touched.
- **`SchoolFieldValidator.swift`** (Shared/Utilities/Validators) — Schools' form
  error strings, out of Schools batch's scope since the file lives in Shared.
- **5 Shared/Components left unwrapped** (`DetailGridItem`, `EmptyStateView`,
  `FormFieldWrapper`, `InfoRow`, `WarningBanner`) — real a11y-corruption risk:
  converting their string param to `LocalizedStringKey` would embed an opaque
  key into a co-located `accessibilityLabel(String(localized: "\(param)..."))`
  interpolation instead of the localized text (one case, `InfoRow`, would have
  been an outright compile break — `LocalizedStringKey` has no `+` operator).
- **Dead code found, left alone (not this plan's job to delete):**
  `PreferenceSuccessToast` (Preferences), `Models/AlertType.swift` +
  `Models/SchoolError.swift` (Schools), `PlaceholderListView.swift`
  (Shared/Components) — all verified zero non-preview callers.
- **`StatusHistoryRow.swift` (Schools)** shows raw backend status strings —
  pre-existing bug verified via git archaeology to predate this plan by 683
  commits. Not a localization miss; unrelated bug.
- **`xcodebuild -exportLocalizations` catalog seeding** — out of scope for the
  whole Phase 6 arc (6a and 6b both), same as documented in 6a's close-out.
- **`planning/2026-08-02-ios-audit-remediation-plan.md`** — referenced as the
  master plan file in earlier phase notes but does not exist in this worktree
  or (as far as checked) `main`. Flag for a future session to either recreate
  it from the phase 1-6 commit trail or formally retire the reference.

## Verification (2026-08-06)

- Clean build: `xcodebuild clean build -scheme TheRecruitingCompass -destination
  'platform=iOS Simulator,name=iPhone 17' -quiet` — exit 0, no new errors, only
  pre-existing warnings (unrelated to this plan: `PieChartView`/`EventRowView`
  result-builder `return` warnings, `HelpFeedbackViewModel` actor-isolation
  warning, etc.).
- Full unit suite: `xcodebuild test -scheme TheRecruitingCompass -destination
  'platform=iOS Simulator,name=iPhone 17' -only-testing:TheRecruitingCompassTests`
  — `** TEST SUCCEEDED **`, 3719 passed, 0 failed. (Baseline at plan-writing time
  was 3720; off-by-one is a test added/removed since, not a regression — 0
  failures either way.) First attempt stalled mid-run on the known
  `RBSRequestErrorDomain`/simulator-launch flake (`NSPOSIXErrorDomain Code=3 "No
  such process"`, 3702/3720 passed with 0 failures before the stall); resolved
  via `xcrun simctl shutdown all && killall -9 CoreSimulatorService` + retry,
  clean on the second attempt.
- Census sanity check: final run matches Task 1's original baseline exactly
  (literal 645, passthrough 431, date-style 6) — expected, see above.
- `scripts/census-text-sites.py` deleted — one-off migration-guidance tool, its
  job is done; keeping it risks going stale and misleading a future audit that
  doesn't deliberately re-validate it.

## Final-review fix wave (2026-08-06)

- **Shared "%@" catalog-key collision (10 sites):** `Text(String(localized:
  "\(param)"))` where `param` is a plain `String` parameter collapses onto a
  shared `"%@"` catalog key instead of keying on the real English text. Fixed
  per-site:
  - **Group A (param type → `LocalizedStringKey`, callers verified
    literal-only):** `HelpSectionDetailView.swift` — `phaseCard`,
    `letterStatusRow`, `notificationPriorityRow` (5 Text call sites, lines
    358/365/377/385/393).
  - **Group B (reverted to plain `Text(param)`, param stays `String` — a11y
    label interpolates the same param, same collision risk Task 7 already
    found for 5 Shared/Components):** `CommunicationTemplatesView.swift:53`,
    `HelpSectionHeader.swift:16`, `HelpImageSlot.swift:25`, and both
    `HelpStepCard.swift` sites (28, 33) — its `accessibilityLabel` interpolates
    both `title` and `bodyText`, so it's Group B, not Group A as originally
    guessed.
- **`UserRole` wrapped** (`Core/Models/UserRole.swift`) — `displayName` and
  `description` now `String(localized:)`, matching the `InteractionType`
  pattern. Deferral reason (cross-feature ownership) didn't hold up on review;
  `rawValue`/persistence untouched. Removed from the deferred-items list above.
- Build clean, `RoleSelectionCardTests` /
  `CommunicationTemplatesAccessibilityTests` / `CommunicationTemplatesViewModelTests`
  pass.
