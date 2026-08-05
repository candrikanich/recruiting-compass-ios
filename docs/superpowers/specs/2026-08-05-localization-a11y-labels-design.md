# Phase 6a — Localization catalog + accessibility-label migration

**Date:** 2026-08-05
**Status:** Approved
**Parent:** `planning/2026-08-02-ios-audit-remediation-plan.md`, Phase 6 (line 176)

## Problem

The app has zero localization infrastructure: no `.xcstrings` catalog, `knownRegions = (en, Base)` only. 1,306 hardcoded user-facing strings exist (661 `accessibilityLabel(...)` call sites + 645 `Text(...)` call sites), none routed through a catalog. This blocks any future non-English release and the retrofit cost grows every sprint new UI ships.

## Scope

**In scope (this plan):**
- Add a `Localizable.xcstrings` String Catalog to the app target.
- Migrate all 661 `accessibilityLabel` call sites so their strings are catalog-backed.
- Stay English-only — no translation work, no second language shipped.

**Out of scope (future plan):**
- The 645 `Text(...)` call sites (separate follow-up phase).
- Actually adding/shipping a second language.
- Non-default catalog key naming (default: literal text is the key).

## Technical approach — REVISED 2026-08-05 after Task 1 implementation

**Original assumption invalidated.** The build has `-emit-localized-strings` / `SWIFT_EMIT_LOC_STRINGS` / `LOCALIZATION_PREFERS_STRING_CATALOGS` all correctly set, but a from-scratch `xcodebuild clean build` did **not** auto-populate `Localizable.xcstrings` — 0 entries extracted, not even the confirmed-present literal `"Sign in to account"`. String Catalog auto-extraction is tied to Xcode's own GUI-driven incremental build database; this repo's workflow is CLI-only (`xcodebuild`, per `CLAUDE.md` — no step anywhere uses the Xcode app), so that mechanism never fires here. Root-caused by the `sdd-task1-impl` subagent (see `.superpowers/sdd/2026-08-05-localization-a11y-labels/task-1-report.md`), confirmed by inspecting `project.pbxproj` build settings directly.

**Revised rule: wrap every `accessibilityLabel` argument in `String(localized:)`, unconditionally — literal, ternary, or interpolated.** This drops the three-bucket split (zero-touch / verify / rewrite) in favor of one uniform mechanical rule. Wrapping literals doesn't get them into the catalog any sooner via CLI than leaving them alone would (extraction still needs a GUI build or `xcodebuild -exportLocalizations` eventually, either way, out of scope for this plan) — but it's still correct and forward-compatible: `String(localized:)` is unambiguous, greppable, and behaves identically once a human does open Xcode and the catalog populates for real.

Site breakdown (measured via grep across `TheRecruitingCompass/TheRecruitingCompass`):

| Category | Count | Action |
|---|---|---|
| Literal-string `accessibilityLabel("...")` | 512 | Mechanical regex wrap — safe, no semantic judgment needed |
| Ternary of two literals (`cond ? "A" : "B"`) | 33 | Wrap the whole ternary expression in `String(localized:)` |
| Interpolated / computed-property labels | 116 | Hand-rewrite to `String(localized:)` with interpolation, feature batch by feature batch (unchanged from original plan) |

Total 661.

### Step 1 — Add the catalog
- Create `Localizable.xcstrings` in `TheRecruitingCompass/TheRecruitingCompass/Core/` (co-located with other cross-cutting resources, consistent with `Assets.xcassets` living near the app root).
- Add it to the app target (file-system-synchronized group — no manual `.xcodeproj` edit needed, per this repo's existing convention).
- Clean build; confirm it succeeds. Do **not** assert on catalog contents — CLI builds don't populate it (see above). That's a known, accepted gap, not a blocker.

### Step 1b — Mechanical wrap of literal + ternary-of-literal sites (545 sites)
A precise, reviewable script transform (Python, not raw `sed`, for correct regex semantics) rewrites every `.accessibilityLabel("...")` and `.accessibilityLabel(cond ? "A" : "B")` call site to wrap its argument in `String(localized:)`. Run project-wide in one pass, build, run the full unit suite (touches many files — worth the full gate once), commit.

### Step 2 — Fix non-literal sites, feature by feature
Rewrite each interpolated/computed accessibility label to use `String(localized:)` with a format-style interpolation, e.g.:

```swift
// Before
.accessibilityLabel("\(count) \(title) offer\(count == 1 ? "" : "s")")

// After
.accessibilityLabel(String(localized: "\(count) \(title) offer\(count == 1 ? "" : "s")"))
```

For computed properties that build a label string (e.g. `statusFilterLabel`), convert the property's return construction the same way at its definition site, not at each call site.

Execution order, smallest feature first to validate the pattern before the big sweeps:
1. `Family`, `Timeline`, `Legal`, `Landing`, `Settings`, `Profile`, `Onboarding`, `About` (1-5 files each)
2. `CommunicationTemplates`, `ActivityFeed`, `Tasks`, `Notifications`, `Help`, `Analytics` (3-9 files each)
3. `Interactions`, `Performance`, `Offers`, `Preferences` (9-13 files each)
4. `Auth`, `Documents`, `Coaches`, `Events`, `Dashboard` (15-18 files each)
5. `Schools` (38 files — largest, last)
6. `Shared/Components` (cross-feature reusable components)

Each batch is one commit: build clean, then move to next batch. Full unit suite run once at the end of the whole migration (not after every batch) — the build catches type/signature errors; the suite catches behavior regressions in the handful of tests that assert on accessibility label values.

## Testing

Existing accessibility unit tests assert on the *string value* of labels (see `MEMORY.md`: labels are read via direct computed-property access in unit tests). `String(localized:)` produces the same runtime string as the raw literal when only the base `en` locale exists — no test rewrites are expected. If any test fails after a batch, that's a real regression to fix before continuing, not a expected/ignorable diff.

## Risks / open questions

- ~~Ternary auto-extraction unconfirmed.~~ **Resolved:** auto-extraction doesn't fire via CLI builds at all, for any site shape. Moot — every site gets wrapped uniformly now (see Technical approach above).
- **Catalog stays empty of real entries until a human builds via Xcode GUI (or runs `xcodebuild -exportLocalizations`) at least once.** That's an accepted, explicit gap in this plan's scope — not a defect to fix here.
- **No visual/behavior change expected** — this is a mechanical string-plumbing change. Any snapshot/UI test relying on exact accessibility identifiers is unaffected (identifiers are separate from labels).

## Localization conventions (added post-final-review)

Going forward, the rule is: wrap the site if there's a literal template — even one with interpolation, e.g. `.accessibilityLabel("Step \(step) of \(total)")` — since a literal template gives `String(localized:)` something to key on. A fully-dynamic value with zero literal content (a bare pass-through parameter, e.g. `.accessibilityLabel(message)` or `.accessibilityLabel("\(value)")` where `value` carries the entire content) may be left as a plain pass-through *or* wrapped as `String(localized: "\(value)")` — both are acceptable for this English-only phase, since they produce identical runtime output. Prefer leaving it **unwrapped** when the value is truly dynamic runtime content (error messages, user-generated text): wrapping doesn't add value until real translation work begins, and an unwrapped pass-through avoids collapsing into a shared `"%@"` catalog key shared with other, unrelated call sites.

The final whole-plan review found that ~14 sites in this plan wrapped a fully-dynamic value unnecessarily. This is a known, accepted inconsistency — not worth unwinding now (churn with no behavior change) — flagged as future cleanup whenever real translation extraction happens.

Accepted exception list — sites deliberately left as unwrapped dynamic pass-throughs:
- `PreferenceSuccessToast.swift` (dead code, no call sites)
- `SchoolAutocompleteDropdown.swift:73`
- `Toast.swift:40`
- `LoadingStateView.swift:14`
- `BadgeView.swift:32`
- `PreferenceLoadingOverlay.swift:15`
- `SuccessToast.swift:17`
- `EventDetailView.swift:247`
