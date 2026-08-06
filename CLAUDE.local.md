# CLAUDE.local.md — phase6b-localization worktree

Not checked into git upstream (worktree-local scratch memory). Records state as of
Phase 6b close-out, 2026-08-06.

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

- **Cross-feature enum `displayName`/`.description` still passthrough:**
  `UserRole` (Core/Models, blocks RoleSelectionCard/SignupView),
  `InteractionType`/`Sentiment` (blocks Coaches/Events), `MetricType` (blocks
  Events/Dashboard). Each is used from 2+ features — wrapping needs a
  cross-feature-owner decision, not a single batch's call.
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
