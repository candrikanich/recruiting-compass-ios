# Phase 6 Legal Pages – Spec Compliance & Implementation Plan

**Specs:** `iOS_SPEC_Phase6_PrivacyPolicy.md`, `iOS_SPEC_Phase6_TermsOfService.md`  
**Date:** February 19, 2026  
**Status:** Partially implemented; gaps documented below with an implementation plan.

---

## 1. Spec Compliance Summary

### 1.1 Implemented (Matches Spec)

| Requirement | Privacy Policy | Terms of Service |
|-------------|----------------|------------------|
| Page with scrollable legal content | ✅ | ✅ |
| All sections (12 / 11) with headers and body text | ✅ | ✅ |
| "Last Updated" date displayed | ✅ | ✅ |
| Back button in toolbar with accessibility | ✅ | ✅ |
| Loading state (spinner + message) | ✅ | ✅ |
| Contact section with gray box (#F3F4F6, 12pt radius) | ✅ | ✅ |
| Email links (mailto:) with 44pt target and VoiceOver label/hint | ✅ | ✅ |
| Models: `PrivacyPolicy` / `TermsOfService` with `lastUpdated`, `formattedDate`, `bundled` | ✅ | ✅ |
| ViewModels: `@Observable`, `@MainActor`, `loadPolicy`/`loadTerms`, `isLoading`, `lastUpdated` | ✅ | ✅ |
| Shared legal components (LegalSectionHeader, LegalSubsectionHeader, LegalBodyText, LegalBulletList, LegalEmailLink) | ✅ | ✅ |
| Entry from Signup (Terms of Service + Privacy Policy links) | ✅ | ✅ |
| Semantic fonts (no fixed point sizes) for Dynamic Type | ✅ | ✅ |
| Section/subsection headers with `.accessibilityAddTraits(.isHeader)` | ✅ | ✅ |
| Unit tests (model, ViewModel, view construction) | ✅ | ✅ |
| Accessibility tests (including placeholders for error/retry) | ✅ | ✅ |
| E2E: Terms sheet from Signup (TermsOfServiceE2ETests) | — | ✅ |

### 1.2 Gaps (Required by Spec, Not Implemented)

| Gap | Spec Reference | Priority |
|-----|----------------|----------|
| **Error state + Retry** | §6 Loading States: Error State with icon, title, subtitle, Retry CTA; §8 Error Handling: "Failed to load" → retry or navigate back; fallback to bundled | **High** |
| **Email app unavailable handling** | §8 User Errors: "Email app not available: Show alert 'Email not available on this device'" | **Medium** |
| **Last Updated alignment** | §6 Layout: "Last Updated: Small, gray, **centered**" | **Low** |
| **Settings entry point** | §2 User Flows: "From **settings**, onboarding, or legal footer link" — only Signup currently | **Medium** |

### 1.3 Optional (Spec Marks as Optional – Not Required for “Fully Implemented”)

- Manage Privacy Settings button (Privacy Policy)
- Accept/Acknowledge flow (scroll-to-bottom, Accept/Decline, record in `legal_acceptances`)
- Dynamic content from Supabase (`legal_documents`); currently bundled only

---

## 2. Implementation Plan

Use existing app patterns: **MVVM**, **@Observable** ViewModels, **ErrorStateView** (or equivalent error UI), **Shared/Components**, **protocol-based services** if adding Supabase later.

### 2.1 Error State + Retry (High)

**Goal:** When load fails (e.g. future dynamic fetch or simulated failure), show spec error UI and Retry; on retry, use bundled content as fallback.

**Files to touch:**

- `Features/Legal/ViewModels/PrivacyPolicyViewModel.swift`
- `Features/Legal/ViewModels/TermsOfServiceViewModel.swift`
- `Features/Legal/Views/PrivacyPolicyView.swift`
- `Features/Legal/Views/TermsOfServiceView.swift`

**Steps:**

1. **ViewModels**
   - Add `var errorMessage: String?` (clear on successful load, set on failure).
   - In `loadPolicy()` / `loadTerms()`: keep current bundled path; optionally set `errorMessage = nil` on success.  
   - For now, do *not* add network calls; leave room for a future `LegalDocumentManaging` service that fetches from Supabase and falls back to bundled on error. When that’s added, set `errorMessage` on failure and use bundled on retry.
   - Add `func retry()` that clears `errorMessage` and calls `loadPolicy()` / `loadTerms()` again (so retry always shows content from bundled if dynamic fails).

2. **Views**
   - After `if viewModel.isLoading`, add branch: `else if let error = viewModel.errorMessage`: show error UI.
   - Error UI (per spec):
     - Icon: `exclamationmark.triangle` (or match `ErrorStateView`), gray, large.
     - Title: "Unable to load Privacy Policy" / "Unable to load Terms of Service".
     - Subtitle: "Please check your connection".
     - Button: "Retry" → call `viewModel.retry()` (e.g. `Task { await viewModel.retry() }`).
   - Reuse or mirror `Shared/Components/ErrorStateView` (message, icon, `onRetry`) so layout and accessibility match the rest of the app. Use spec copy for title/subtitle and ensure Retry has 44pt min height and hint e.g. "Retries loading Privacy Policy" / "Retries loading Terms of Service".

3. **Accessibility**
   - Error icon: `accessibilityHidden(true)` (message conveys meaning).
   - Retry: `accessibilityLabel("Retry")`, `accessibilityHint("Retries loading Privacy Policy")` (or Terms).
   - Existing tests in `PrivacyPolicyAccessibilityTests` already expect error view and retry hint; ensure implementation matches.

4. **Tests**
   - ViewModel: when `retry()` is called, `errorMessage` is cleared and load runs again; when load succeeds, `errorMessage` is nil.
   - If you later add a failing path (e.g. mock service), test that error state appears and retry shows content (bundled).

**Note:** With current bundled-only load, error state will only appear if you introduce a failure path (e.g. for testing or when adding Supabase). That’s acceptable; the spec’s “fallback to bundled” is satisfied when retry loads bundled after a failed fetch.

### 2.2 Email App Unavailable (Medium)

**Goal:** If the device cannot open Mail for `mailto:`, show alert: "Email not available on this device."

**Files to touch:**

- `Features/Legal/Components/LegalContentViews.swift` (`LegalEmailLink`)

**Steps:**

1. In `LegalEmailLink`, replace plain `Link(email, destination: url)` with a button (or equivalent) that:
   - Calls `UIApplication.shared.canOpenURL(url)` (or uses a small helper that checks Mail availability if needed for iOS version).
   - If can open: `UIApplication.shared.open(url)`.
   - If cannot open: set a local `@State var showMailUnavailableAlert = true` and present an alert with title/message "Email not available on this device."
2. Ensure the tappable area remains at least 44pt and accessibility label/hint unchanged.
3. Add a unit or UI test that, when Mail is unavailable (or mocked), the alert is shown.

**Reference:** Spec §8 User Errors.

### 2.3 Last Updated Centered (Low)

**Goal:** Match spec: "Last Updated: Small, gray, **centered**."

**Files to touch:**

- `Features/Legal/Views/PrivacyPolicyView.swift`
- `Features/Legal/Views/TermsOfServiceView.swift`

**Steps:**

1. In the `ScrollView` content (e.g. the `VStack` that contains "Last Updated" and sections), wrap the "Last Updated" text in an `HStack` with `Spacer()` before and after, or use `.frame(maxWidth: .infinity)` and `.multilineTextAlignment(.center)` so the line is centered.
2. Keep font (e.g. `.caption`) and color (e.g. `Color.secondaryText`).

### 2.4 Settings Entry Point (Medium)

**Goal:** User can open Privacy Policy and Terms of Service from Settings, not only from Signup.

**Files to touch:**

- `Features/Settings/Views/SettingsView.swift`

**Steps:**

1. Add a "Legal" or "About" section (or append to an existing section) with two rows:
   - "Terms of Service" → navigation or sheet to `TermsOfServiceView()`.
   - "Privacy Policy" → navigation or sheet to `PrivacyPolicyView()`.
2. Use the same sheet pattern as Signup: e.g. `@State private var showTerms = false`, `@State private var showPrivacy = false`, and `.sheet(isPresented:)` for each, with Back/dismiss in the legal views.
3. Match existing Settings style (e.g. `SettingsRow` with icon, title, short description).
4. Optional: add a simple E2E that opens Settings, taps Terms or Privacy, and dismisses.

---

## 3. Optional / Future Work (Out of Scope for “Spec Complete”)

- **Dynamic content:** Add `LegalDocumentManaging` service, fetch from Supabase `legal_documents` by type (`privacy_policy` / `terms_of_service`), use bundled as fallback; cache by version.
- **Accept/Acknowledge:** Modal with scroll-to-bottom detection, Accept/Decline buttons, POST to `legal_acceptances`; gate on first launch or version change.
- **Manage Privacy Settings:** Button/link in Privacy Policy view that navigates to app Settings (or a dedicated privacy preferences screen).

---

## 4. Verification Checklist (After Implementation)

- [ ] Privacy Policy: error state shows with spec title/subtitle and Retry; retry loads content (bundled).
- [ ] Terms of Service: same error/retry behavior.
- [ ] Retry button: 44pt min height, accessibility label and hint per spec.
- [ ] Email links: when Mail cannot be opened, alert "Email not available on this device" appears.
- [ ] Last Updated: centered in both legal views.
- [ ] Settings: Legal section with Terms of Service and Privacy Policy; both open correct view and dismiss.
- [ ] `make test` (unit + UI) passes; existing Legal and accessibility tests still pass.

---

## 5. References

- **Specs:** `recruiting-compass-web/planning/iOS_SPEC_Phase6_PrivacyPolicy.md`, `iOS_SPEC_Phase6_TermsOfService.md`
- **App patterns:** `CLAUDE.md`, `docs/CODE_PATTERNS.md`, `TheRecruitingCompass/UI/Screens/HOW_TO_CREATE_SCREENS.md`
- **Shared components:** `Shared/Components/ErrorStateView.swift`, `Features/Legal/Components/LegalContentViews.swift`
