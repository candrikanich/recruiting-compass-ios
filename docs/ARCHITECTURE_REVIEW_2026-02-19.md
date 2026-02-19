# Architecture Review: Performance, Efficiency, Security, Standards & UX

**Date:** February 19, 2026  
**Scope:** Recruiting Compass iOS — Swift/SwiftUI, MVVM, Supabase, Features (Auth, Dashboard, ActivityFeed, Schools, Coaches, Legal, Settings), Core, Shared.

This review focuses on **performance**, **efficiencies**, **security**, **standards**, and **user experience**, with actionable recommendations and priorities. It complements the existing `ARCHITECTURE_REVIEW.md` and reflects recent work (Legal feature, ActivityFeed realtime lifecycle, Legal ViewModels with `nonisolated deinit`).

---

## Executive Summary

The app has a **solid foundation**: clear MVVM separation, protocol-based DI, Keychain-backed auth, consistent accessibility patterns, and a strong test suite (126+ tests). The main opportunities are **performance** (caching, parallel loading, realtime lifecycle already improved), **efficiency** (reducing duplication, standardizing patterns), **security** (credentials handling, input validation consistency), **standards** (documenting `nonisolated deinit`, DI consistency), and **UX** (error/retry and loading consistency).

**Top recommendations:** (1) Add a lightweight cache layer for frequently re-visited screens; (2) Standardize and document `nonisolated deinit` for all @MainActor ViewModels used in tests/sheets; (3) Avoid placeholder Supabase config in production; (4) Use shared loading/error components where still duplicated; (5) Document Legal and ActivityFeed patterns in CODE_PATTERNS.

---

## 1. Performance

### 1.1 Data Loading & Caching

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| ViewModels often re-fetch on every appearance (e.g. `SchoolDetailView`, `CoachDetailView`, Legal docs). | **Medium** | Introduce a simple in-memory cache with TTL for detail screens (e.g. `CacheManaging` protocol, keyed by id + optional TTL). Use for school detail, coach detail, and optionally for list data with short TTL. |
| Legal documents (Privacy Policy, Terms) load bundled data only; no network. `load()` is async and sets `lastUpdated` — already efficient. | Low | No change; consider removing async from `load()` if you ever make it sync (e.g. load from bundle synchronously) to avoid unnecessary task hops. |
| ActivityFeed: initial load + realtime subscribe in `RecentActivityWidget`; lifecycle is well handled (background cleanup, cancel on disappear). | — | Current pattern (capture `realtimeService` before nil, run unsubscribe in background task, cancel on active) is correct. No change. |

**Files:** `Features/Schools/ViewModels/SchoolDetailViewModel.swift`, `Features/Coaches/ViewModels/CoachDetailViewModel.swift`, `Features/ActivityFeed/Components/RecentActivityWidget.swift`, `Features/Legal/ViewModels/PrivacyPolicyViewModel.swift`.

### 1.2 Concurrency & Threading

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| ViewModels are consistently `@MainActor`; services are not, with `@unchecked Sendable` where needed (SupabaseManager, KeychainHelper). | — | Good. Keep. |
| `nonisolated deinit {}` used in ActivityFeedViewModel, PrivacyPolicyViewModel, TermsOfServiceViewModel to avoid deinit-on-wrong-executor crashes in tests/sheets. | **Medium** | Document in `docs/CODE_PATTERNS.md` and apply to any other @MainActor ViewModels that are used in sheets or UIHostingController tests. Prefer one short comment per ViewModel pointing to the pattern. |
| ActivityRealtimeService is an `actor`; subscribe/unsubscribe and channel cleanup are correct. | — | No change. |

**Files:** `Core/Services/SupabaseManager.swift`, `Core/Utilities/KeychainHelper.swift`, `Features/ActivityFeed/ViewModels/ActivityFeedViewModel.swift`, `Features/Legal/ViewModels/PrivacyPolicyViewModel.swift`, `Features/Legal/ViewModels/TermsOfServiceViewModel.swift`, `docs/CODE_PATTERNS.md`.

### 1.3 Realtime Lifecycle

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| RecentActivityWidget: on background, service is captured, `realtimeService` nilled, unsubscribe runs in a cancellable task; on active, task is cancelled and loadAndSubscribe runs again. | — | Correct. No change. |
| `onDisappear` captures service and nils reference before firing async unsubscribe. | — | Correct. No change. |

**File:** `Features/ActivityFeed/Components/RecentActivityWidget.swift`.

---

## 2. Efficiencies

### 2.1 Code Reuse & Duplication

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Legal: Shared `LegalSectionHeader`, `LegalSubsectionHeader`, `LegalBodyText`, `LegalBulletList`, `LegalEmailLink` in `LegalContentViews.swift`; Privacy Policy and Terms views use them. | — | Good. Keep. |
| Legal: `LegalDocument` enum with `view` and `.sheet(item:)` used from SignupView and SettingsView — single pattern for presenting either document. | — | Good. Keep. |
| Legal ViewModels (PrivacyPolicy, TermsOfService) share protocol `LegalDocumentLoading` and similar structure (load, retry, errorMessage). TermsOfServiceViewModel duplicates the same pattern as PrivacyPolicyViewModel. | **Low** | Optional: introduce a generic or shared helper for “load lastUpdated from bundled model” to reduce duplication between the two ViewModels. Not blocking. |
| ErrorStateView is shared; Legal and other features use it with retry. | — | Good. Ensure any new feature uses `ErrorStateView` (and shared loading components) instead of custom error UIs. |
| Loading: Some views use ad-hoc `ProgressView` + text; shared `LoadingStateView` exists. | **Low** | Prefer `LoadingStateView` (or a single shared loading component) everywhere for consistency. |

**Files:** `Features/Legal/Components/LegalContentViews.swift`, `Features/Legal/Models/LegalDocument.swift`, `Features/Legal/Protocols/LegalDocumentLoading.swift`, `Shared/Components/ErrorStateView.swift`, `Shared/Components/LoadingStateView.swift`.

### 2.2 Dependency Injection

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Many ViewModels use optional DI with `.shared` / default implementations (e.g. `SchoolsListViewModel`, `SchoolDetailViewModel`, `AddSchoolViewModel` convenience init). | — | Good for production; tests override with mocks. |
| Legal ViewModels (PrivacyPolicy, TermsOfService) have no service dependency; they load from bundled models only. | — | Appropriate. No DI needed. |
| ActivityFeedViewModel uses `AuthManager.shared` and likely an activity service; realtime is injected via `ActivityRealtimeService(supabaseManager: .shared)` in the view. | **Low** | Consider injecting `ActivityRealtimeManaging` into the ViewModel (or a dedicated coordinator) for testability of realtime behavior; current approach is acceptable if E2E covers it. |

**Files:** `Features/Schools/ViewModels/SchoolsListViewModel.swift`, `Features/Schools/ViewModels/SchoolDetailViewModel.swift`, `Features/ActivityFeed/ViewModels/ActivityFeedViewModel.swift`, `Features/ActivityFeed/Components/RecentActivityWidget.swift`.

### 2.3 Feature Structure

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Features follow Models / ViewModels / Views / Components (and Services where needed). Legal fits: Models (PrivacyPolicy, TermsOfService, LegalDocument), ViewModels, Views, Components, Protocols. | — | Good. Keep. |
| Naming: ViewModels/Views/Services/Protocols follow project conventions. | — | Good. Keep. |

---

## 3. Security

### 3.1 Authentication & Session

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Auth: Session stored in Keychain via `KeychainHelper`; keys are fixed (`savedSession`). KeychainHelper uses `kSecClassGenericPassword`, service identifier, and account key. | — | Good. |
| Session restore: Valid session refreshed; expired session requires successful refresh or clear. Fallback to cached session when refresh fails but cache still valid. | — | Good. |
| Logout: Local state cleared and Keychain deleted even if `signOut()` fails. | — | Good. |

**Files:** `Core/Services/AuthManager.swift`, `Core/Utilities/KeychainHelper.swift`.

### 3.2 Credentials & Configuration

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Supabase URL and anon key come from `ProcessInfo.processInfo.environment`; fallback to placeholder URL/key when unset. | **High** | Ensure production builds never use the placeholder (e.g. fail fast or assert in Release if env is missing, or use a build-time config so placeholder is only in Debug/Testing). Document in CLAUDE.md / README. |
| Shared scheme has empty placeholders; real credentials in local (unshared) scheme. | — | Good. Keep. |

**File:** `Core/Services/SupabaseConfig.swift`, `CLAUDE.md`.

### 3.3 Input Validation & Sanitization

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| `DataSanitizer`: `nilIfEmpty`, `stripAtSign`, `stripHtmlTags` (XSS mitigation). Used where forms/schools/coaches prepare data. | — | Good. |
| Form validation: `FormValidator`, `SchoolFieldValidator`, etc., used across forms. | — | Good. |
| Recommendation | **Low** | Ensure any new user-editable text that is stored or displayed (e.g. notes, bios) runs through appropriate sanitization (e.g. `stripHtmlTags` for rich text). Add a short “Security & validation” note to CODE_PATTERNS or a security checklist. |

**Files:** `Shared/Utilities/Validators/DataSanitizer.swift`, `Shared/Utilities/FormValidator.swift`, `docs/CODE_PATTERNS.md`.

---

## 4. Standards

### 4.1 MVVM & Layers

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Services are data-only (no UI state); ViewModels are @Observable, @MainActor, with clear state and async methods; Views bind to ViewModel state and call methods. | — | Aligns with CLAUDE.md. Keep. |
| Legal: ViewModels conform to `LegalDocumentLoading`; Views use `.task { await viewModel.load() }` and show loading/error/content. | — | Consistent. |

### 4.2 Naming & Conventions

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| ViewModels: *Feature*ViewModel; Views: *Feature*View; Services: *Feature*Service or *Feature*ServiceImpl; Protocols: *Feature*Managing / *Feature*Loading. | — | Good. Keep. |

### 4.3 Testing & Accessibility

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| 126+ tests; unit, integration, accessibility, E2E; naming *Tests, *IntegrationTests, *AccessibilityTests, *E2ETests. | — | Good. |
| CODE_PATTERNS documents UIHostingController + @MainActor ViewModel teardown issues and `nonisolated deinit` workaround. | **Medium** | Add a short “nonisolated deinit” section that lists when to use it (ViewModels in sheets or tested via UIHostingController) and point to ActivityFeedViewModel and Legal ViewModels as references. |
| Accessibility: semantic fonts, 44pt targets, labels/hints, ErrorStateView and Legal components use accessibility modifiers. | — | Good. Keep. |

**Files:** `docs/CODE_PATTERNS.md`, `CLAUDE.md`, `Shared/Components/ErrorStateView.swift`, `Features/Legal/Components/LegalContentViews.swift`.

---

## 5. User Experience

### 5.1 Navigation & Presentation

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Legal: Single `LegalDocument` enum and `.sheet(item:)` from Signup and Settings; Terms and Privacy open in sheet with Back. | — | Consistent. Good. |
| Deep link: Reset password handled in app; `showResetPassword` sheet. | — | Good. |

**Files:** `Features/Auth/Views/SignupView.swift`, `Features/Settings/Views/SettingsView.swift`, `Features/Legal/Models/LegalDocument.swift`, `TheRecruitingCompassApp.swift`.

### 5.2 Error Handling & Retry

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Legal: Error state with `ErrorStateView`, message + retry; ViewModels expose `errorMessage` and `retry()`. | — | Good. |
| Shared `ErrorStateView` used for Legal and elsewhere; retry and accessibility hint supported. | — | Good. |
| Recommendation | **Low** | Where errors are still shown only via alert or inline text, consider replacing with ErrorStateView for consistency (full-screen error + retry where appropriate). |

**Files:** `Features/Legal/Views/PrivacyPolicyView.swift`, `Features/Legal/Views/TermsOfServiceView.swift`, `Shared/Components/ErrorStateView.swift`.

### 5.3 Loading States

| Finding | Priority | Recommendation |
|--------|----------|----------------|
| Legal and others show loading (e.g. ProgressView + “Loading…”). | — | Good. |
| Recommendation | **Low** | Standardize on `LoadingStateView` (or one shared component) and consistent copy (“Loading…” vs “Loading Terms…” vs “Loading Privacy Policy…”) for predictability. |

---

## 6. Prioritized Action List

### High

1. **Production Supabase config**  
   Ensure production never uses placeholder URL/key. Fail fast or use build-time config; document in CLAUDE.md/README.

### Medium

2. **Cache layer for detail screens**  
   Add a simple in-memory cache (e.g. `CacheManaging` with TTL) and use it for School detail, Coach detail (and optionally lists with short TTL) to reduce redundant fetches.

3. **Document `nonisolated deinit`**  
   In CODE_PATTERNS, add a subsection describing when and why to use `nonisolated deinit {}` on @MainActor ViewModels, with references to ActivityFeedViewModel and Legal ViewModels.

4. **Consistent use of shared loading/error components**  
   Audit views that still use custom loading/error UI and migrate to `LoadingStateView` / `ErrorStateView` where it improves consistency.

### Low

5. **Optional: generic Legal “last updated” loader**  
   If you add more legal documents, consider a shared helper for “load formatted date from bundled model” to avoid duplicating the same logic.

6. **Optional: inject ActivityRealtimeManaging**  
   For easier unit testing of realtime behavior, inject the realtime service into the ViewModel or a small coordinator instead of constructing it in the view.

7. **Security/validation note in CODE_PATTERNS**  
   Short checklist: sanitize user text (e.g. stripHtmlTags), validate inputs, never log secrets, production config.

---

## 7. Summary for the Team

The Recruiting Compass iOS app is in good shape: **MVVM is applied consistently**, **auth and session handling are secure** (Keychain, clear logout, session refresh with fallback), **realtime lifecycle is correct** (background unsubscribe, no leaks), and **Legal and Settings** use a single, reusable pattern for Terms and Privacy. **Accessibility and testing** are strengths.

**Top follow-ups:** (1) **Security:** Ensure production never uses placeholder Supabase config. (2) **Performance:** Add a small cache for detail screens to avoid repeated network calls. (3) **Standards:** Document the `nonisolated deinit` pattern for @MainActor ViewModels used in sheets/tests. (4) **Efficiency/UX:** Standardize on shared loading and error components everywhere. (5) **Legal/ActivityFeed:** Already aligned with the rest of the app; document these patterns in CODE_PATTERNS for future features.

Implementing the high and medium items will improve performance, security, and maintainability with minimal risk; low-priority items can be done opportunistically.
