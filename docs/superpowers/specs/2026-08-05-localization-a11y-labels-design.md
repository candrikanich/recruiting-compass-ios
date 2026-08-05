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

## Technical approach

The build already runs with `-emit-localized-strings` (confirmed in build logs — `SWIFT_EMIT_LOC_STRINGS` is on). This means Xcode's compiler-based extraction auto-populates a String Catalog from any argument typed as `LocalizedStringKey` that is a literal at the call site — **without any code change** at that call site, as long as the catalog file exists and is a target member.

Site breakdown (measured via grep across `TheRecruitingCompass/TheRecruitingCompass`):

| Category | Count | Action |
|---|---|---|
| Literal-string `accessibilityLabel("...")` | 512 | Zero code change — auto-extracted once catalog exists |
| Ternary of two literals (`cond ? "A" : "B"`) | 33 | Verify auto-extraction; leave as-is if catalog picks them up |
| Interpolated / computed-property labels | 116 | Rewrite to `String(localized:)` with interpolation, so the *template* (not the runtime value) becomes the catalog key |

Total 661.

### Step 1 — Add the catalog
- Create `Localizable.xcstrings` in `TheRecruitingCompass/TheRecruitingCompass/Core/` (co-located with other cross-cutting resources, consistent with `Assets.xcassets` living near the app root).
- Add it to the app target (file-system-synchronized group — no manual `.xcodeproj` edit needed, per this repo's existing convention).
- Clean build, then inspect the generated catalog to confirm literal strings from a couple of known files (e.g. `LoginView.swift`) appear as entries. This validates the auto-extraction assumption before doing any manual work.

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

- **Ternary auto-extraction unconfirmed.** If Xcode's extractor does *not* pick up ternaries-of-literals despite `LocalizedStringKey` typing, those 33 sites move into the manual-rewrite bucket (Step 2 pattern). Verify in Step 1 before committing to "zero-touch" for that subset.
- **No visual/behavior change expected** — this is a mechanical string-plumbing change. Any snapshot/UI test relying on exact accessibility identifiers is unaffected (identifiers are separate from labels).
