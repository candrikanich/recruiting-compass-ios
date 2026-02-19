# Architecture Review: Recruiting Compass iOS

This document provides prioritized recommendations to improve **performance**, **efficiency**, **security**, **standards compliance**, and **user experience** for the Recruiting Compass iOS app. It is based on a review of Core, Features, Shared layers, CLAUDE.md, CODE_PATTERNS.md, and recent branch changes (Legal, ActivityFeed, SupabaseConfig).

---

## Summary

| Area        | High | Medium | Low |
|------------|------|--------|-----|
| Performance | 2   | 2      | 1   |
| Efficiency  | 1   | 2      | 1   |
| Security    | 2   | 1      | 0   |
| Standards   | 1   | 2      | 1   |
| User Experience | 0 | 2   | 1   |

**Patterns to preserve:** MVVM with @Observable/@MainActor, protocol-based DI for services, shared LoadingStateView/ErrorStateView, Legal shared components, CacheManaging + TTL caches, Release-build credential enforcement, nonisolated deinit where needed for teardown.

---

## 1. Performance

### High

**1.1 InMemoryCache: avoid decoding on every get**

- **Where:** `Core/Utilities/CacheManaging.swift` — `InMemoryCache.get` decodes from `Data` on every call.
- **Issue:** Repeated decode for the same key (e.g. school detail) adds CPU and allocates; no cache-wide memory cap.
- **Recommendation:** Consider a small in-memory object cache (e.g. by key) for hot types used by SchoolDetailViewModel, with the same TTL, so repeated visits within TTL avoid decode. Optionally add a max entry count or memory pressure observer and evict oldest entries.

**1.2 LegalDocumentLoader is synchronous; “load” is misleading**

- **Where:** `Features/Legal/Utilities/LegalDocumentLoader.swift`, `PrivacyPolicyViewModel.load()` / `TermsOfServiceViewModel.load()`.
- **Issue:** `loadLastUpdated` only validates a pre-formatted string; the async `load()` still shows a loading state and can “fail” on empty formatted date, which is confusing and adds perceived latency.
- **Recommendation:** Either (a) make Legal document content truly async (e.g. load from bundle/remote with a real async path) and keep loading/error states, or (b) if content is always bundled, derive lastUpdated synchronously and remove the fake async loading state so the screen appears instantly. Prefer (b) if there is no remote legal source.

### Medium

**1.3 School list distance cache is unbounded**

- **Where:** `Features/Schools/ViewModels/SchoolsListViewModel.swift` — `distanceCache: [String: Double]` grows with every school ever shown.
- **Recommendation:** Cap size (e.g. LRU or max count) or clear when filters change significantly so the list doesn’t hold distances for hundreds of schools indefinitely.

**1.4 Realtime subscription lifecycle**

- **Where:** `Features/ActivityFeed/Components/RecentActivityWidget.swift` — `onChange(of: scenePhase)` and `onDisappear` now capture `realtimeService` and use a `backgroundCleanupTask` to avoid races.
- **Note:** Current pattern (cancel task, capture service, nil out, then async unsubscribe) is correct. Preserve it when adding new realtime or long-lived subscriptions elsewhere.

### Low

**1.5 CollegeScorecardCache / NcaaDatabase cache expiry**

- **Where:** `CollegeScorecardService.swift` (actor cache with TTL), `NcaaDatabase` (in-memory lookup cache).
- **Recommendation:** Document TTL/expiry and whether caches are ever cleared on memory warning; consider clearing or trimming on `UIApplication.didReceiveMemoryWarningNotification` if lists can be very large.

---

## 2. Efficiency

### High

**2.1 SupabaseManager is a singleton with no protocol**

- **Where:** `Core/Services/SupabaseManager.swift`, `AuthManager` and various ViewModels/services.
- **Issue:** AuthManager and others call `SupabaseManager.shared` directly. Integration tests use the real manager where possible; unit testing auth in isolation requires either a protocol or test-only overrides.
- **Recommendation:** Introduce a `SupabaseManaging` protocol (e.g. signIn, signUp, signOut, refreshSession, getCurrentSession) and inject it into AuthManager (and any other direct callers). Keep `SupabaseManager` as the default implementation. This aligns with the existing “protocol-based DI” standard and improves testability and flexibility.

### Medium

**2.2 CacheManaging used only by SchoolDetailViewModel**

- **Where:** `Core/Utilities/CacheManaging.swift`, `SchoolDetailViewModel`.
- **Recommendation:** Reuse the same pattern for other heavy, reloadable resources (e.g. coach detail, document metadata) where a short TTL is acceptable. This reduces duplicate network calls and keeps behavior consistent.

**2.3 LegalDocumentLoading protocol and LegalDocumentLoader**

- **Where:** `Features/Legal/Protocols/LegalDocumentLoading.swift`, `LegalDocumentLoader.loadLastUpdated`.
- **Issue:** Loader only validates a string; the protocol is useful for consistency but the “load” contract suggests I/O.
- **Recommendation:** If legal content stays bundled, rename or document that “load” is validation/formatting only; if you add remote legal content later, extend the loader to perform real async work and keep the protocol.

### Low

**2.4 Duplication between TermsOfServiceView and PrivacyPolicyView**

- **Where:** Both views share LoadingStateView, ErrorStateView, LegalSectionHeader, LegalBodyText, etc., but each has its own section layout.
- **Recommendation:** Already well factored with shared components. Any further shared “legal document shell” (toolbar, loading/error, scroll container) could be a single reusable view parameterized by title and content.

---

## 3. Security

### High

**3.1 Interaction subject/content not sanitized for HTML**

- **Where:** `Features/Interactions/Models/InteractionCreateRequest.swift` — comment says “Sanitize text fields (basic HTML/XSS prevention)” but only trims; `subject` and `content` are not passed through `DataSanitizer.stripHtmlTags`.
- **Issue:** User-supplied subject/content could contain HTML/script and be stored or later rendered, increasing XSS risk.
- **Recommendation:** Apply `DataSanitizer.stripHtmlTags` to `subject` and `content` (and any other user-generated text in this flow) before assignment, consistent with `CoachCreateRequest+Preparation` and `SchoolCreateRequest+Preparation`. Re-run any interaction-related tests and manual checks.

**3.2 Release credentials and Scheme documentation**

- **Where:** `SupabaseConfig.swift`, CLAUDE.md, README.md.
- **Current state:** Release builds fatalError if SUPABASE_URL/SUPABASE_ANON_KEY are missing or placeholder — good.
- **Recommendation:** In CI and release runbooks, explicitly document that Release/Archive must have these env vars set (e.g. Scheme → Run → Environment Variables or CI secrets). Consider a single “Configuration” or “Deployment” doc that links to CLAUDE.md and lists all required env vars and where to set them for dev vs release.

### Medium

**3.3 Keychain service/account naming**

- **Where:** `Core/Utilities/KeychainHelper.swift` — service = `"com.chrisandrikanich.TheRecruitingCompass"`; AuthManager uses account `"savedSession"`.
- **Recommendation:** Ensure the same service/account scheme is used after any app identifier or team change (e.g. production bundle ID) so sessions are not lost. Document the key names in one place (e.g. CODE_PATTERNS or a short Security section in docs).

---

## 4. Standards

### High

**4.1 CODE_PATTERNS: @Published vs @Observable**

- **Where:** Comments in `AddSchoolViewModel+Autocomplete.swift`, `AddSchoolViewModel+DuplicateDetection.swift`, etc., still say “@Published” in a few places.
- **Issue:** Project standard is @Observable (see CLAUDE.md, CODE_PATTERNS.md). Outdated comments can mislead.
- **Recommendation:** Grep for “@Published” in comments and update to “observable properties (@Observable)” so it matches the actual pattern and CODE_PATTERNS.

### Medium

**4.2 Screen template and HOW_TO_CREATE_SCREENS**

- **Where:** CLAUDE.md references `_ScreenTemplate/` and `HOW_TO_CREATE_SCREENS.md`.
- **Recommendation:** If the template still says ObservableObject/@Published, update it to @Observable and the “@State private var viewModel” pattern so new screens are created to current standards by default.

**4.3 Error alert binding pattern**

- **Where:** CODE_PATTERNS.md describes a derived Binding for `.alert(isPresented:)` so the alert can be dismissed by clearing the message.
- **Recommendation:** Audit views that show error alerts and ensure they use this pattern (or an equivalent that clears `errorMessage` on dismiss) so behavior is consistent and users can dismiss and retry without stale alerts.

### Low

**4.4 Test naming and placement**

- **Where:** Test files mirror source structure; naming follows *Tests, *IntegrationTests, *AccessibilityTests, *E2ETests.
- **Recommendation:** When adding features (e.g. Legal), add corresponding unit tests for ViewModels and any new utilities (e.g. LegalDocumentLoader if it gains real logic). Keep one place (e.g. README or CLAUDE) that lists the test commands (make test, make test-unit, make test-unit-fast) so CI and developers stay aligned.

---

## 5. User Experience

### Medium

**5.1 Legal document loading/error UX**

- **Where:** PrivacyPolicyView and TermsOfServiceView show loading then content or error with retry.
- **Issue:** If “load” is only validation of a bundled string, the loading state may flash unnecessarily; if validation fails (e.g. empty formatted date), the error message could be clearer.
- **Recommendation:** Tie UX to the Performance recommendation 1.2: if you remove fake async loading, the flash goes away; if you keep async, ensure error messages are user-friendly (e.g. “We couldn’t load this document. Please try again.”) and that retry is obviously available (already using ErrorStateView).

**5.2 Session loading and deep links**

- **Where:** TheRecruitingCompassApp shows sessionLoadingView while `authManager.isCheckingSession` is true; deep link handler sets `showResetPassword` for resetPassword.
- **Recommendation:** Ensure that when the app is opened via a reset-password link while not yet authenticated, the session check completes (or is skipped for that route) and the reset password sheet is still shown so the user doesn’t land on login with no indication that the link was handled.

### Low

**5.3 Accessibility of loading and error states**

- **Where:** LoadingStateView and ErrorStateView are used across the app; some usages may not combine loading/error with a single accessibility element.
- **Recommendation:** Confirm that loading and error states are announced correctly with VoiceOver (e.g. “Loading schools” / “Unable to load schools. Retry button.”) and that focus moves appropriately when transitioning from loading to content or error. Existing accessibility tests are a good baseline; add or extend for any new flows (e.g. Legal sheets).

---

## Implementation Priority

1. **Security:** Apply `DataSanitizer.stripHtmlTags` to interaction subject/content (3.1).
2. **Standards:** Replace remaining “@Published” comments with “@Observable” (4.1).
3. **Performance/UX:** Resolve Legal “load” semantics — either remove loading state for bundled content or add real async and keep clear error messages (1.2, 5.1).
4. **Efficiency:** Introduce SupabaseManaging and inject into AuthManager (2.1).
5. **Performance:** Consider object cache or decode reuse for InMemoryCache hot paths (1.1).
6. **Efficiency:** Document and optionally cap SchoolsListViewModel distance cache (1.3).
7. **Security:** Document Release env vars and Keychain keys (3.2, 3.3).
8. **Standards:** Update screen template and error-alert audit (4.2, 4.3).

---

## References

- `CLAUDE.md` — Architecture, testing, accessibility, env config
- `docs/CODE_PATTERNS.md` — ViewModel, View, Service, error alerts, security checklist
- `docs/TROUBLESHOOTING.md` — Common issues
- `docs/ACCESSIBILITY_AUDIT.md` — Accessibility testing
- Branch diff: SupabaseConfig Release fatalError, Legal feature, ActivityFeed lifecycle, ViewModel nonisolated deinit
