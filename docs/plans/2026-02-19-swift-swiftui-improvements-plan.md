# Implementation Plan: Swift/SwiftUI Code Review Suggestions

**Created:** 2026-02-19  
**Source:** [SWIFT_SWIFTUI_CODE_REVIEW.md](../SWIFT_SWIFTUI_CODE_REVIEW.md)  
**Goal:** Implement the suggested improvements in a low-risk, incremental order.

---

## Priority and Order

| Phase | Item | Effort | Risk | Dependency |
|-------|------|--------|------|------------|
| 1 | Theme consistency (ErrorStateView) | Small | Low | None |
| 2 | Update AddSchoolViewModel extension comments | Small | None | None |
| 3 | Open URL via Environment (LegalEmailLink) | Small | Low | None |
| 4 | Shared date formatting for Legal "Last updated" | Small | Low | None |
| 5 | Shared Legal document ViewModel abstraction | Medium | Low | Phase 4 optional |
| 6 | LocalizedStringKey / String catalog (legal + error copy) | Medium | Low | None (can run in parallel) |
| 7 | Optional: nonisolated deinit on Legal ViewModels | Small | Low | Only if tests show crashes |
| 8 | Optional: .sheet(item:) for Legal in Settings | Small | Low | Only if adding more legal docs |

---

## Phase 1: ErrorStateView Theme Consistency

**File:** `TheRecruitingCompass/Shared/Components/ErrorStateView.swift`

- Change the message `Text` from `.foregroundStyle(.secondary)` to `.foregroundStyle(Color.secondaryText)` (or the project’s semantic secondary text color).
- Run unit/UI tests that use **ErrorStateView**; confirm appearance in light/dark.

**Done when:** Build and relevant tests pass; visual check in Settings/Legal error states.

---

## Phase 2: AddSchoolViewModel Extension Comments

**Files:**

- `TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel+Autocomplete.swift`
- `TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel+Enrichment.swift`
- `TheRecruitingCompass/Features/Schools/ViewModels/AddSchoolViewModel+DuplicateDetection.swift`

- Replace references to “@Published properties” with “observable properties” (or “@Observable-backed properties”) in comments that describe where state lives.

**Done when:** Comments accurately reflect current @Observable usage.

---

## Phase 3: LegalEmailLink – Prefer openURL Environment

**File:** `TheRecruitingCompass/Features/Legal/Components/LegalContentViews.swift`

- Add **@Environment(\.openURL) private var openURL** to **LegalEmailLink** (or the view that performs the open).
- In the mailto button action, call **openURL(url)** instead of **UIApplication.shared.open(url)** when running in an environment that provides **openURL** (e.g. full app).
- If the app still supports a deployment target where **openURL`** is not available, keep a fallback to **UIApplication.shared.open(url)** behind an availability check if needed.
- Preserve existing behavior: same alert when the URL cannot be opened.

**Done when:** Mailto links still open Mail (or show “Email not available”); no regressions in Legal sheets.

---

## Phase 4: Shared “Last Updated” Date Formatting

**Files:**

- `TheRecruitingCompass/Features/Legal/Models/PrivacyPolicy.swift` (or equivalent)
- `TheRecruitingCompass/Features/Legal/Models/TermsOfService.swift`

- Introduce a shared date formatter (e.g. **DateFormatter.legalDocumentDate** or a small helper in **Legal** or **Shared/Utilities**).
- Have **PrivacyPolicy** and **TermsOfService** use this formatter in their **formattedDate`** (or equivalent) so “Last updated” is consistent and one place controls locale/calendar behavior.

**Done when:** Privacy Policy and Terms of Service “Last updated” look and behave the same; unit tests for Legal models still pass.

---

## Phase 5: Shared Legal Document ViewModel Abstraction (Optional)

**Files:**

- New: optional protocol or base type in **Features/Legal/ViewModels/** (e.g. **LegalDocumentViewModel** protocol or a single generic ViewModel).
- **PrivacyPolicyViewModel** and **TermsOfServiceViewModel**: refactor to use the shared abstraction (e.g. conform to protocol or call into shared implementation).

- Design so **loadPolicy** / **loadTerms** and **retry** are implemented once; **lastUpdated**, **isLoading**, **errorMessage** stay consistent.
- Keep **PrivacyPolicyView** and **TermsOfServiceView** unchanged in behavior; only the ViewModel implementation changes.

**Done when:** No duplicate load/retry/error logic; existing Legal tests and UI behavior unchanged.

---

## Phase 6: LocalizedStringKey / String Catalog (Optional but Recommended)

**Scope:** At least Legal and shared error copy (e.g. ErrorStateView, Legal views).

- Add a String catalog (e.g. **Localizable.xcstrings**) if the project does not have one.
- Replace hard-coded user-facing strings in Legal views and **ErrorStateView** with **LocalizedStringKey** or catalog keys (e.g. navigation titles, “Back”, “Retry”, “Loading …”, “Unable to load …”).
- Keep default language as English; no need to add other languages in this phase.

**Done when:** All reviewed strings are localizable; app behavior and appearance unchanged for the default language.

---

## Phase 7: nonisolated deinit on Legal ViewModels (Only If Needed)

**When:** Only if you see test crashes when deallocating **PrivacyPolicyViewModel** or **TermsOfServiceViewModel** (e.g. in **UIHostingController**-based tests).

**What:** Add **nonisolated deinit {}** to **PrivacyPolicyViewModel** and **TermsOfServiceViewModel**, with a one-line comment pointing to the same pattern used in **ActivityFeedViewModel**.

**Done when:** Affected tests run without deinit-related crashes.

---

## Phase 8: .sheet(item:) for Legal in Settings (Only If Scaling)

**When:** Only if you add more legal/document sheets (e.g. Licenses, Consent) and want to avoid multiple booleans.

**What:**

- Define an enum, e.g. **LegalDocument: Identifiable** with cases such as **.terms**, **.privacy**, and optionally **.licenses**, etc.
- In **SettingsView**, replace **showTermsOfService** / **showPrivacyPolicy** with **@State private var presentedLegal: LegalDocument?**.
- Use a single **.sheet(item: $presentedLegal)** and switch on the enum to present **TermsOfServiceView()** or **PrivacyPolicyView()** (and future views).
- Wire existing buttons to set **presentedLegal = .terms** / **.privacy**.

**Done when:** Behavior unchanged; adding a new legal document only requires one new enum case and one view in the switch.

---

## Verification

After each phase:

1. **Build:** `make build` (or project’s build command).
2. **Tests:** `make test-unit` (or equivalent); run any Legal/Settings/ErrorState UI or accessibility tests.
3. **Manual:** Open Legal from Signup and Settings; trigger error states; test mailto link and “Last updated” display.

---

## Rollback

- Each phase is independent; revert the corresponding commits if needed.
- Phase 5 and 6 touch more files; consider a feature branch and PR for those.
