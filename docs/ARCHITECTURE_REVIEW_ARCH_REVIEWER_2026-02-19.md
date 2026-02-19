# Architecture Review: Recruiting Compass iOS

**Date:** February 19, 2026  
**Scope:** Performance, efficiencies, security, standards, and user experience  
**Method:** Codebase exploration + file-level analysis

---

## Executive Summary

The Recruiting Compass iOS app has a **strong foundation**: clear MVVM separation, protocol-based DI (AuthManaging, SupabaseManaging, CacheManaging, CoachesManaging), Keychain-backed auth, Release credential enforcement, and consistent accessibility patterns. The test suite (126+ tests) and feature structure are well-organized.

**Top Recommendations:**

| Priority | Area | Recommendation |
|----------|------|----------------|
| 1 | **Performance** | Add object-layer cache for InMemoryCache hot paths (e.g., coach/school detail) to avoid repeated JSON decode. |
| 2 | **Security** | Centralize configuration docs: env vars, Keychain keys, deployment checklist in `docs/CONFIGURATION.md`. |
| 3 | **Standards** | Document `nonisolated deinit` pattern in CODE_PATTERNS; update any remaining @Published/ObservableObject references. |
| 4 | **UX** | Ensure reset-password deep link works when app opens unauthenticated; gate network-dependent actions with NetworkMonitor. |
| 5 | **Efficiency** | Standardize `handleError` / `withLoading` (ViewModelHelpers) across all ViewModels; extend caching to Offer and Document detail. |

---

## 1. Performance

### 1.1 Data Loading & Caching

**Current State:**
- `CacheManaging` protocol with `InMemoryCache` (TTL, max 200 entries, LRU eviction)
- `CoachDetailViewModel` uses cache (coach:60s TTL); cache invalidated on mutations
- `SchoolDetailViewModel` uses cache
- `InMemoryCache.get` decodes from `Data` on every call; no object cache

| Finding | Recommendation |
|---------|----------------|
| Repeated visits to the same coach/school within TTL trigger JSON decode on every load. | Add optional in-memory object cache for hot keys, or use `AnyCodable`-style typed storage to skip decode on cache hit. |
| Dashboard loads stats, tasks, suggestions, events sequentially. | Use `async let` or `TaskGroup` for independent fetches to reduce perceived latency. |
| SchoolsListViewModel.distanceCache (300 entries); cleared on reload. | — Good. |
| Legal documents (Privacy Policy, Terms) load synchronously from bundled models. | — Correct; no loading flash. |

**Files:** `CoachDetailViewModel`, `SchoolDetailViewModel`, `CacheManaging.swift`, `InMemoryCache`, `DashboardViewModel`.

### 1.2 Concurrency & Threading

| Finding | Recommendation |
|---------|----------------|
| ViewModels consistently `@MainActor`; services non-actor, `Sendable` where needed. | — Keep current pattern. |
| `nonisolated deinit {}` used in ActivityFeedViewModel, PrivacyPolicyViewModel, TermsOfServiceViewModel. | Document in `docs/CODE_PATTERNS.md` when to use (ViewModels in sheets or tested via UIHostingController). Already partially documented. |
| ActivityRealtimeService lifecycle (background unsubscribe, cancel on appear). | — Keep. Background cleanup and `backgroundCleanupTask` pattern are correct. |

### 1.3 Memory & External APIs

| Finding | Recommendation |
|---------|----------------|
| CollegeScorecardService, NcaaDatabase use in-memory caches with TTL. | Add `didReceiveMemoryWarning` trimming for very large caches if they grow unbounded. |

---

## 2. Efficiencies

### 2.1 Code Reuse

| Finding | Recommendation |
|---------|----------------|
| Legal shared components (LegalSectionHeader, LegalBodyText, LegalBulletList, LegalEmailLink). | — Good; reuse for new legal content. |
| `ViewModelHelpers.withLoading` and `ViewModelHelpers.handleError` exist; not all ViewModels use them. | Standardize on these helpers to reduce duplication and ensure consistent error handling. |
| ErrorStateView, LoadingStateView exist. | Prefer shared components for all list/detail screens. |
| CacheManaging used by School and Coach detail. | Extend to Offer and Document detail where applicable. |

### 2.2 Dependency Injection

| Finding | Recommendation |
|---------|----------------|
| AuthManager injects `SupabaseManaging`; CoachesServiceImpl injects SupabaseManager. | — Good. |
| Some services still use `SupabaseManager.shared` directly. | Prefer protocol injection for testability. |
| ActivityRealtimeService created in view; not injected into ViewModel. | Optional: inject for easier testing. |
| `InMemoryCache.shared` used as default in CoachDetailViewModel. | — Good; cache is injectable for tests. |

### 2.3 Feature Structure

Features follow `Models / ViewModels / Views / Components / Services` consistently. — Keep.

---

## 3. Security

### 3.1 Authentication & Session

| Finding | Recommendation |
|---------|----------------|
| Session stored in Keychain; restore, refresh, logout flows correct. | — Good. |
| KeychainHelper uses fixed service; session key `savedSession`. | Document in `docs/CONFIGURATION.md`; ensure keys stay consistent after bundle ID changes. |

### 3.2 Credentials & Configuration

| Finding | Recommendation |
|---------|----------------|
| Release builds `fatalError` if SUPABASE_URL or SUPABASE_ANON_KEY missing/placeholder. | — Correct. |
| Placeholder only in DEBUG. | — Good. |
| Env vars and Keychain keys scattered across README, CLAUDE.md. | Add `docs/CONFIGURATION.md` listing all env vars, Keychain keys, dev vs release setup. |

### 3.3 Input Validation & Sanitization

| Finding | Recommendation |
|---------|----------------|
| `InteractionCreateRequest` uses `DataSanitizer.stripHtmlTags` on subject/content. | — Done. |
| Coach and School create/update use DataSanitizer. | — Good. |
| CODE_PATTERNS has "Security & validation" checklist. | — Keep; ensure all new user-editable fields follow it. |

### 3.4 Deep Links

| Finding | Recommendation |
|---------|----------------|
| DeepLinkHandler validates scheme (`recruiting-compass`) and host (`reset-password`); token from query. | — Good. |
| Reset-password token passed to ResetPasswordView; Supabase validates server-side. | — Correct; token never trusted client-side for auth. |
| Deep link handled while `authManager.isCheckingSession` may still be true. | Verify reset-password sheet appears after session check when app opens via link while unauthenticated. |

---

## 4. Standards

### 4.1 MVVM & Conventions

| Finding | Recommendation |
|---------|----------------|
| Services data-only; ViewModels @Observable, @MainActor; Views bind and call methods. | — Aligns with CLAUDE.md. |
| CLAUDE.md updated for @Observable and "no UI state in services." | — Good. |
| Screen template and HOW_TO_CREATE_SCREENS. | Ensure they use @Observable and `@State private var viewModel`. |

### 4.2 Testing & Accessibility

| Finding | Recommendation |
|---------|----------------|
| 126+ tests; unit, integration, accessibility, E2E. | — Good. |
| Mock pattern (AuthManaging, MockAuthManager) used consistently. | Extend mocks for SupabaseManaging, CacheManaging where tests need isolation. |
| Semantic fonts, accessibilityLabel, accessibilityHint, min 44x44 targets. | — WCAG AA–oriented; maintain. |

---

## 5. User Experience

### 5.1 Offline & Network

| Finding | Recommendation |
|---------|----------------|
| NetworkMonitor (NWPathMonitor) exists; OfflineBanner shown when `!networkMonitor.isConnected`. | — Good. |
| NetworkMonitor injected via environment. | — Good. |
| Network errors surface via `errorMessage` in ViewModels. | Ensure all network-dependent screens handle offline consistently (e.g., retry, message). |
| ActivityRealtimeService unsubscribes when app goes to background. | — Correct. |

### 5.2 Loading & Error States

| Finding | Recommendation |
|---------|----------------|
| Shared LoadingStateView, ErrorStateView exist. | Use consistently across features. |
| Session loading shows splash + ProgressView. | — Good. |
| Legal views load synchronously; no loading state needed. | — Correct. |

### 5.3 Accessibility

| Finding | Recommendation |
|---------|----------------|
| Semantic fonts, VoiceOver labels, hit targets. | — Maintain. |
| OfflineBanner uses `.accessibilityElement(children: .combine)`. | — Good. |

---

## 6. Prioritized Action Items

### High Priority

1. **CONFIGURATION.md** – Single doc for env vars, Keychain keys, dev/release setup.
2. **nonisolated deinit** – Document in CODE_PATTERNS when to add and which ViewModels use it.
3. **Reset-password deep link** – Confirm sheet appears when app opens via link while session check is in progress.

### Medium Priority

4. **InMemoryCache hot path** – Add object cache or decode reuse for frequently accessed keys.
5. **ViewModelHelpers** – Standardize `withLoading` / `handleError` across ViewModels.
6. **Extend caching** – Use CacheManaging for Offer and Document detail screens.

### Low Priority

7. **Dashboard parallelization** – Use `async let` for independent fetches.
8. **Protocol injection** – Prefer protocols for remaining direct SupabaseManager usage.
9. **Memory warning** – Add trimming to large external caches if they grow significantly.

---

## 7. Strengths Summary

- Clear MVVM separation and protocol-based DI
- Keychain-backed session; Release credential enforcement
- DataSanitizer used for user text (XSS mitigation)
- InMemoryCache with TTL and LRU; Coach and School detail use it
- NetworkMonitor + OfflineBanner for offline UX
- Consistent @Observable, @MainActor, nonisolated deinit where needed
- 126+ tests and accessibility patterns

---

## References

- `CLAUDE.md` – Quick start, architecture overview, testing
- `docs/CODE_PATTERNS.md` – ViewModel, View, Service, security patterns
- `docs/CONFIGURATION.md` – (To create) env vars, Keychain, deployment
- `docs/ARCHITECTURE_REVIEW_2026-02-19_CONSOLIDATED.md` – Prior review
