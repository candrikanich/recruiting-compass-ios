# Architecture Review: Recruiting Compass iOS

**Date:** February 19, 2026  
**Scope:** Performance, efficiency, security, standards, and user experience  
**Reflects:** Current branch state (SupabaseManaging, Legal, Release credential enforcement, DataSanitizer on interactions, etc.)

---

## Executive Summary

The Recruiting Compass iOS app has a **strong foundation**: clear MVVM separation, protocol-based DI (AuthManaging, SupabaseManaging, CacheManaging), Keychain-backed auth, Release credential enforcement, and consistent accessibility patterns. The test suite (126+ tests) and feature structure are well-organized.

**Top recommendations:**

1. **Performance:** Extend `CacheManaging` to Coach detail and other detail screens; consider object cache or decode reuse for `InMemoryCache` hot paths.
2. **Standards:** Document `nonisolated deinit` pattern in CODE_PATTERNS; update any remaining @Published/ObservableObject comments.
3. **Security:** Document Keychain keys and env vars in a single Configuration/Deployment doc.
4. **UX:** Ensure network/offline errors surface consistently; add `NWPathMonitor` for proactive offline messaging where appropriate.
5. **Efficiency:** Extend caching beyond School detail; standardize `handleError` / `withLoading` helpers across ViewModels.

---

## 1. Performance

### 1.1 Data Loading & Caching

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| **SchoolDetailViewModel** uses `CacheManaging` with 60s TTL; **CoachDetailViewModel** and others do not. | Medium | Extend the same cache pattern to Coach detail and other frequently revisited detail screens. |
| **InMemoryCache.get** decodes from `Data` on every call. | Medium | For hot keys (e.g. school detail), add an optional object cache layer or decode reuse so repeated visits within TTL avoid JSON decode. |
| **SchoolsListViewModel.distanceCache** capped at 300 entries and cleared on reload. | — | Already good. |
| **Dashboard** loads stats, tasks, suggestions, events, metrics, trends sequentially. | Low | Consider parallelizing independent fetches (e.g. `async let` for stats + suggestions + events) where dependencies allow. |
| Legal documents (Privacy Policy, Terms) load from bundled models synchronously. | — | Correct. No loading flash. |

**Files:** `SchoolDetailViewModel`, `CoachDetailViewModel`, `CacheManaging.swift`, `DashboardViewModel`, `SchoolsListViewModel`.

### 1.2 Concurrency & Threading

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| ViewModels consistently `@MainActor`; services non-actor with `@unchecked Sendable` where needed. | — | Good. |
| `nonisolated deinit {}` used in ActivityFeedViewModel, PrivacyPolicyViewModel, TermsOfServiceViewModel. | Medium | Document in `docs/CODE_PATTERNS.md` when to use (ViewModels in sheets or tested via UIHostingController) and reference these ViewModels. |
| ActivityRealtimeService actor; RecentActivityWidget lifecycle (background cleanup, cancel on appear) correct. | — | Keep current pattern. |

### 1.3 External APIs

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| CollegeScorecardService and NcaaDatabase use in-memory caches with TTL. | Low | Document TTL and consider trimming on memory warning for very large lists. |

---

## 2. Efficiency

### 2.1 Code Reuse

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| Legal shared components (LegalSectionHeader, LegalBodyText, LegalBulletList, LegalEmailLink). | — | Good. |
| `OfferDetailViewModel` has `handleError` and `withLoading`; many others use ad-hoc `isLoading`/`errorMessage` and inline error handling. | Low | Extract a shared `ViewModelHelpers` or mixin for `handleError`/`withLoading` to reduce duplication. |
| ErrorStateView and LoadingStateView exist but not all views use them. | Low | Prefer shared components for new features. |
| CacheManaging used only by SchoolDetailViewModel. | Medium | Reuse for Coach, Offer, and Document detail where applicable. |

### 2.2 Dependency Injection

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| AuthManager, SchoolsServiceImpl, etc. inject SupabaseManager (or protocol). | — | Good. SupabaseManaging now in place for auth. |
| Many services use `SupabaseManager.shared` directly. | Low | Prefer protocol injection for services to improve testability where practical. |
| ActivityRealtimeService created in view; not injected into ViewModel. | Low | Optional: inject for easier testing. |

### 2.3 Feature Structure

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| Features follow Models / ViewModels / Views / Components / Services. | — | Good. Keep. |

---

## 3. Security

### 3.1 Authentication & Session

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| Session in Keychain; restore, refresh, and logout flows correct. | — | Good. |
| KeychainHelper uses fixed service/account keys. | Low | Document in Configuration/Deployment doc; ensure consistency after bundle ID changes. |

### 3.2 Credentials & Configuration

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| Release builds `fatalError` if SUPABASE_URL/ANON_KEY missing or placeholder. | — | Correct. CLAUDE.md and README mention it. |
| Placeholder only in DEBUG. | — | Good. |
| Recommendation | Medium | Add a single `docs/CONFIGURATION.md` (or expand existing) listing all env vars, Keychain keys, and where to set them for dev vs release. |

### 3.3 Input Validation & Sanitization

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| `InteractionCreateRequest` uses `DataSanitizer.stripHtmlTags` on subject/content. | — | Done. |
| Coach and School create requests use DataSanitizer. | — | Good. |
| Recommendation | Low | Add a short "Security & validation" checklist in CODE_PATTERNS for new user-editable fields. |

---

## 4. Standards

### 4.1 MVVM & Conventions

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| Services data-only; ViewModels @Observable, @MainActor; Views bind and call methods. | — | Aligns with CLAUDE.md. |
| Some comments still reference @Published or ObservableObject. | Low | Grep and update to @Observable. |
| Screen template and HOW_TO_CREATE_SCREENS. | Low | Ensure they use @Observable and @State private var viewModel. |

### 4.2 Testing & Accessibility

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| 126+ tests; naming *Tests, *IntegrationTests, *AccessibilityTests, *E2ETests. | — | Good. |
| Accessibility: semantic fonts, 44pt targets, labels/hints. | — | Good. |
| `nonisolated deinit` documented in CODE_PATTERNS. | Medium | Add section explaining when and why; point to ActivityFeedViewModel and Legal ViewModels. |

---

## 5. User Experience

### 5.1 Error & Loading States

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| Error messages vary (generic vs specific); ErrorStateView used in many places. | — | Generally consistent. |
| No global network reachability handling. | Medium | Consider `NWPathMonitor` to show a banner or toast when offline; surfaces "check connection" before user hits errors. |
| Deep link for reset-password while unauthenticated. | Low | Verify reset-password sheet appears after session check when opened via deep link. |

### 5.2 Navigation & Presentation

| Finding | Priority | Recommendation |
|---------|----------|----------------|
| Legal uses LegalDocument enum and `.sheet(item:)` from Signup and Settings. | — | Consistent. |
| Pull-to-refresh and retry patterns used where appropriate. | — | Good. |

---

## Prioritized Action Items

| Priority | Area | Action |
|----------|------|--------|
| 1 | Standards | Document `nonisolated deinit` in CODE_PATTERNS |
| 2 | Security | Create/update `docs/CONFIGURATION.md` with env vars and Keychain keys |
| 3 | Performance | Extend CacheManaging to CoachDetailViewModel (and optionally Offer detail) |
| 4 | Performance | Consider object cache or decode reuse for InMemoryCache hot paths |
| 5 | Efficiency | Extract shared `handleError`/`withLoading` helpers for ViewModels |
| 6 | UX | Evaluate NWPathMonitor for proactive offline messaging |
| 7 | Standards | Replace remaining @Published/ObservableObject comments with @Observable |
| 8 | Efficiency | Reuse LoadingStateView/ErrorStateView where ad-hoc loading/error UI exists |

---

## References

- `CLAUDE.md` — Architecture, testing, env config
- `docs/CODE_PATTERNS.md` — ViewModel, Service, error alerts
- `docs/TROUBLESHOOTING.md` — Common issues
- `docs/ACCESSIBILITY_AUDIT.md` — Accessibility testing
- `docs/ARCHITECTURE_REVIEW_2026-02-19.md` — Previous review snapshot
- `docs/ARCHITECTURE_REVIEW_RECOMMENDATIONS.md` — Previous recommendations (many addressed in branch)
