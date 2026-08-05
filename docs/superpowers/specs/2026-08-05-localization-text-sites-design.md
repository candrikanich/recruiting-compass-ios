# Phase 6b — Localization: Text() call sites

**Date:** 2026-08-05
**Status:** Approved
**Parent:** Master plan `planning/2026-08-02-ios-audit-remediation-plan.md`, Phase 6 (per `handoff-2026-08-04-ios-audit-phase5-multitype-split.md`). Note: this master plan file could not be located on disk or in git history at design time (checked `main`, all local branches, `origin/worktree-audit-phase0`) — handoffs reference it but it appears to have been lost when the prior worktree was deleted uncommitted. This spec stands on its own; Phase 6a's completed spec (`2026-08-05-localization-a11y-labels-design.md`) is the direct precedent.

## Problem

Phase 6a (merged, PR #29) migrated all 661 `accessibilityLabel` call sites to `String(localized:)`. The master plan's remaining item is the `Text(...)` call sites, originally estimated at 645. A fresh census at design time found **1,103–1,107** `Text(` sites in app source (`TheRecruitingCompass/TheRecruitingCompass/`) — the 645 figure from the original audit is stale/unreconciled, same kind of drift the Phase 5.1 handoff already noted for its own file-count estimate (73 vs. 109). Not investigated further — doesn't change the technical approach, just the site count.

## Key technical difference from 6a

`accessibilityLabel(_:)` takes a plain `String` — no compiler-assisted localization exists, so 6a wrapped every site uniformly in `String(localized:)`.

`Text` has a dedicated initializer, `Text(_ key: LocalizedStringKey, ...)`, alongside a verbatim `Text<S: StringProtocol>(_ content: S)` overload. Swift's overload resolution picks the `LocalizedStringKey` initializer for string-literal arguments (including interpolated literals — `LocalizedStringKey` conforms to `ExpressibleByStringInterpolation`, with interpolated non-literal values becoming format arguments, not key content). This means:

- `Text("Some label")` — **already catalog-backed**, zero-touch.
- `Text("Prefix \(x) suffix")` — **already catalog-backed**, zero-touch (the interpolation becomes a format argument, the literal parts form the key).
- `Text(someString)` where `someString: String` — resolves to the **verbatim overload**, not localized. Needs fixing.
- `Text(cond ? "A" : "B")` — the ternary's static type is `String` (inferred from two literal branches with no `LocalizedStringKey` context), so this also hits the verbatim overload despite looking literal. Needs fixing.

## Census (app source, `TheRecruitingCompass/TheRecruitingCompass/`, excludes `_ScreenTemplate`)

| Bucket | Count | Action |
|---|---|---|
| Plain literal `Text("...")` | 531 | Zero-touch — already `LocalizedStringKey`-backed |
| Interpolated literal `Text("...\(x)...")` | 110 | Zero-touch — same reason |
| Variable/expression pass-through (`Text(x)`, ternary-of-literals) | 462 | **Fix** — wrap at definition site |
| Other (`Text(verbatim:)`, `Text(date, style:)`/`format:`, `Text(Image(...))`) | ~4–8 | Case-by-case, expected no-op (already correct or non-textual) |

Total ≈ 1,103–1,107. Only the 462-site pass-through bucket requires code changes.

## Scope

**In scope:**
- Fix all pass-through `Text()` sites (~462) by wrapping the underlying `String`-producing definition in `String(localized:)`.
- Document the zero-touch literal/interpolated buckets (641+ sites) — no code change, but the reasoning is recorded here and in the follow-up commit message so it isn't mistaken for missed work in a future audit.
- Apply 6a's dynamic-content exception convention: genuinely dynamic runtime values (error messages, user-generated text) may stay unwrapped.

**Out of scope:**
- Catalog seeding via `xcodebuild -exportLocalizations` — stays deferred, same as 6a. This phase is pure code-plumbing.
- Translating to a second language.
- The `Text(verbatim:)` / `Text(date, style:)` / `Text(Image(...))` edge-case bucket — audit only, no changes expected unless the census script finds a genuine miscategorized site.

## Technical approach

### Step 1 — Census script
Adapt 6a's Python census script (not raw regex/sed — needs correct handling of nested parens, ternaries, multi-line calls) to classify every `Text(` call site in app source into:
1. Literal / interpolated-literal → skip, log as zero-touch.
2. Pass-through (identifier, member access, function call, ternary-of-literals) → candidate for fixing.
3. Edge cases (`verbatim:`, `date, style:`/`format:`, wraps an `Image`) → skip, log separately for a quick manual scan (not full fix pass).

Within bucket 2, cross-reference against 6a's already-wrapped `String(localized:)` properties (grep `String(localized:` across the codebase first) — any property already wrapped for `accessibilityLabel` needs no re-wrap; the `Text()` call site consuming it is already correct as-is. Flag these as "already covered" rather than re-touching them.

### Step 2 — Fix pass-through sites, feature by feature
For each remaining candidate, wrap at the **definition site** (the computed property, `displayName`, enum case label, or formatter function that produces the `String`) — not at the `Text(x)` call. Rationale (same as 6a Step 2): fewer edits, and the fix propagates correctly to any other consumer of the same property (e.g. a `Text` and an `accessibilityLabel` both reading `status.displayName`).

```swift
// Before
var displayName: String {
  switch self {
  case .pending: return "Pending"
  case .accepted: return "Accepted"
  }
}

// After
var displayName: String {
  switch self {
  case .pending: return String(localized: "Pending")
  case .accepted: return String(localized: "Accepted")
  }
}
```

For ternary-of-literals directly in a view (no shared property to wrap), wrap the ternary expression at the call site:
```swift
// Before
Text(isExpanded ? "Hide" : "Calculate")
// After
Text(isExpanded ? String(localized: "Hide") : String(localized: "Calculate"))
```

Apply 6a's dynamic-content exception: leave truly dynamic pass-throughs (error strings, user-generated text with no literal template) unwrapped. Document exceptions in this file's "Localization conventions" section (below), same format as 6a's accepted-exception list.

### Step 3 — Batch order
Reuse 6a's exact feature order (validated low-risk-first sequencing):
1. `Family`, `Timeline`, `Legal`, `Landing`, `Settings`, `Profile`, `Onboarding`, `About`
2. `CommunicationTemplates`, `ActivityFeed`, `Tasks`, `Notifications`, `Help`, `Analytics`
3. `Interactions`, `Performance`, `Offers`, `Preferences`
4. `Auth`, `Documents`, `Coaches`, `Events`, `Dashboard`
5. `Schools`
6. `Shared/Components`

One commit per batch: build clean before moving to the next batch. Full unit suite run once at the end of the whole migration.

## Testing

Same as 6a: existing tests that assert on displayed/label string values continue to pass, because `String(localized:)` returns the same runtime string as the raw literal when only the base `en` locale exists. A test failure after a batch is a real regression, not an expected diff.

## Risks / open questions

- **Overlap with 6a-wrapped properties.** The census script must detect properties already wrapped in `String(localized:)` (from 6a) and skip them for `Text()` purposes — the property is already correct, only the never-wrapped ones need touching. Double-wrapping (`String(localized: String(localized: "..."))`) would compile but is meaningless churn; the census step exists specifically to prevent it.
- **Master plan file missing.** `planning/2026-08-02-ios-audit-remediation-plan.md` doesn't exist on disk or in any git history searched. Not blocking — this spec is self-contained — but the master plan's "execution status" tracking (referenced by every prior handoff as the source of truth) is effectively gone. Worth recreating or formally retiring that reference after this phase, flagged for a future session, not fixed here.
- **Stale site-count estimate.** 645 (plan) vs. 1,103–1,107 (fresh census) — unreconciled, consistent with the same drift Phase 5.1 saw in its own counts. Not investigated further; doesn't change scope since only ~462 of the total need real changes regardless of which total figure is "correct."

## Localization conventions (carried forward from 6a, extended for Text())

Same rule as 6a: wrap the site if there's a literal template to key on, even with interpolation. Leave truly dynamic runtime content unwrapped (error messages, user-generated text) — wrapping adds no value pre-translation and avoids collapsing distinct call sites into a shared `"%@"` catalog key.

Exception list — sites deliberately left as unwrapped dynamic pass-throughs — to be populated during Step 2 execution as real cases are found (mirrors 6a's exception list, which was also finalized during implementation, not upfront).
