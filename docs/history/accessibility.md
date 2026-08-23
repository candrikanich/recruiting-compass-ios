# Accessibility History

## 2026-08-05 — Localization Phase 6 (a11y labels + text sites)
Added the `Localizable.xcstrings` catalog and routed ~661 `accessibilityLabel` sites plus ~431 pass-through `Text()` sites through `String(localized:)` (mechanical wrap + per-feature hand rewrites; dynamic content left unwrapped).

## 2026-03-19 — Dropped UIHostingController a11y unit tests
Deleted 62 permanently-skipping UIHostingController-based a11y unit tests. Key insight: SwiftUI's accessibility tree is not introspectable in unit tests; coverage belongs in XCUIApplication E2E a11y tests.

## WCAG Audit Results (various sessions, 2026)
Audits completed for: Dashboard, Activity Feed, Interactions, Schools (AddSchool, SchoolDetail), Coaches (AddCoach), Preferences, Family Management. All critical findings resolved. Key patterns: `accessibilityElement(children: .combine)` for label+value pairs, `accessibilityHidden(true)` for decorative icons, minimum 44pt tap targets on all interactive elements, `accessibilityLabel`/`accessibilityHint` on all buttons.

## Dynamic Type (2026-02-06)
59 hard-coded font sizes and 71 fixed spacing values replaced with semantic fonts across 13 files. All body/label text uses semantic fonts (`.body`, `.headline`, `.subheadline`, etc.). SF Symbol icons use `@Environment(\.sizeCategory)`-derived sizes. See `docs/VISUAL_QA_TESTING_GUIDE.md` for test matrix.

## Preferences Accessibility Fixes (2026)
Critical a11y fixes applied to Preferences: segmented control role announcements, toggle state announcements, picker accessibility labels, grouped form fields as combined accessibility elements.

## Family Management Accessibility Audit (2026)
Family management screens (family member list, invite flow, role display) passed accessibility audit. Combined elements used for member cards, roles announced correctly via `.accessibilityValue`.
