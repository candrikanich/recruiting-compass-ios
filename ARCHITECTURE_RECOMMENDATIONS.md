# Architectural Recommendations - Priority Implementation Guide

## Overview

This document provides actionable, prioritized recommendations from the comprehensive architecture review (see `ARCHITECTURE_REVIEW.md`). Focus on high-priority items first—they provide the most value with minimal effort.

---

## Priority 1: High Impact, Quick Wins (This Sprint)

### 1.1 Parallelize Independent Data Fetches

**Status:** ⚡ Quick Fix (30 minutes)
**Impact:** 30-50% faster list loading
**Complexity:** Low

**File to Modify:**
`/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Features/Coaches/ViewModels/CoachesListViewModel.swift`

**Current Code (Lines 86-109):**
```swift
func loadCoaches() async {
  guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
    logger.warning("No familyUnitId available")
    errorMessage = "Unable to load coaches. Please try again."
    return
  }

  isLoading = true
  errorMessage = nil
  defer { isLoading = false }

  do {
    let schools = try await coachesService.fetchSchools(familyUnitId: familyUnitId)
    allSchools = schools

    let schoolIds = schools.map(\.id)
    allCoaches = try await coachesService.fetchCoaches(schoolIds: schoolIds)

    logger.info("Loaded \(self.allCoaches.count) coaches from \(schools.count) schools")
  } catch {
    logger.error("Failed to load coaches: \(error.localizedDescription)")
    errorMessage = "Failed to load coaches: \(error.localizedDescription)"
  }
}
```

**Problem:**
- Schools fetched first, then coaches (sequential)
- If schools request is fast but coaches is slow, user waits unnecessarily

**Recommended Fix:**
```swift
func loadCoaches() async {
  guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
    logger.warning("No familyUnitId available")
    errorMessage = "Unable to load coaches. Please try again."
    return
  }

  isLoading = true
  errorMessage = nil
  defer { isLoading = false }

  do {
    // CHANGE: Parallel fetch if possible
    async let schoolsTask: [School] = coachesService.fetchSchools(familyUnitId: familyUnitId)

    // If coaches API accepts familyUnitId instead of schoolIds,
    // fetch in parallel here
    // Otherwise, fetch schools first then coaches

    let schools = try await schoolsTask
    allSchools = schools

    let schoolIds = schools.map(\.id)
    let coaches = try await coachesService.fetchCoaches(schoolIds: schoolIds)
    allCoaches = coaches

    logger.info("Loaded \(self.allCoaches.count) coaches from \(schools.count) schools")
  } catch {
    logger.error("Failed to load coaches: \(error.localizedDescription)")
    errorMessage = "Failed to load coaches: \(error.localizedDescription)"
  }
}
```

**Alternative (if coaches API supports familyUnitId):**
```swift
do {
  async let schoolsTask = coachesService.fetchSchools(familyUnitId: familyUnitId)
  async let coachesTask = coachesService.fetchCoaches(familyUnitId: familyUnitId)

  let (schools, coaches) = try await (schoolsTask, coachesTask)
  allSchools = schools
  allCoaches = coaches

  logger.info("Loaded \(coaches.count) coaches from \(schools.count) schools")
} catch {
  // error handling
}
```

**How to Verify:**
- Check `CoachesManaging` protocol to see if `fetchCoaches()` can accept `familyUnitId` directly
- Profile with Instruments: Time Profile → compare before/after

**Testing:**
```swift
func testLoadCoaches_ParallelFetch() async {
  mockService.mockSchools = [makeTestSchool(id: "1"), makeTestSchool(id: "2")]
  mockService.mockCoaches = [makeTestCoach(), makeTestCoach()]

  await viewModel.loadCoaches()

  // Verify both calls were made
  XCTAssertEqual(mockService.fetchSchoolsCallCount, 1)
  XCTAssertEqual(mockService.fetchCoachesCallCount, 1)
}
```

---

### 1.2 Add Session Expiry Buffer

**Status:** ⚡ Critical Security Fix (15 minutes)
**Impact:** Prevents edge-case authentication failures
**Complexity:** Minimal

**File to Modify:**
`/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift`

**Current Code (Lines 141-147):**
```swift
if savedSession.expiresAt > now {
  // Session still valid — refresh to get latest user data, fall back to cached on failure
  await refreshAndSaveSession(fallback: savedSession)
} else {
  // Session expired — must successfully refresh or clear all state
  await refreshAndSaveSession(fallback: nil)
}
```

**Problem:**
- Session checked at exact expiry time
- Network request takes 100-500ms
- By the time refresh completes, session has expired at server
- Edge case: Fails despite being "valid"

**Recommended Fix:**
```swift
if savedSession.expiresAt > now + 300 { // 5-minute buffer
  // Session still valid — refresh to get latest user data, fall back to cached on failure
  await refreshAndSaveSession(fallback: savedSession)
} else if savedSession.expiresAt > now {
  // Session expiring soon — refresh without fallback
  await refreshAndSaveSession(fallback: nil)
} else {
  // Session expired — must successfully refresh or clear all state
  await refreshAndSaveSession(fallback: nil)
}
```

**Why 5 Minutes?**
- Typical network round-trip: 100-500ms
- Supabase token refresh: 1-2 seconds
- User interaction time: 1-3 seconds
- Safety margin: 5 minutes handles all cases

**Testing:**
```swift
func testRestoreSession_RefreshesWhenExpiringSoon() async {
  let now = Int(Date().timeIntervalSince1970)
  let almostExpired = now + 200 // Expires in 200 seconds
  let session = Session(..., expiresAt: almostExpired)

  try keychain.save(session, forKey: "savedSession")
  await authManager.restoreSession()

  // Should trigger refresh, not use fallback
  XCTAssertEqual(mockSupabase.refreshSessionCallCount, 1)
}
```

---

## Priority 2: Medium Impact, Medium Effort (Next 1-2 Sprints)

### 2.1 Implement Simple Caching Layer

**Status:** 🛠️ Medium Effort (4-6 hours)
**Impact:** 40-60% reduction in API calls
**Complexity:** Medium

**Rationale:**
- CoachDetailViewModel loads same coach data repeatedly on navigation
- Events list re-fetches on every tab switch
- Coaches list reloads unnecessarily

**Step 1: Create Cache Protocol**

File: `Features/Shared/Services/CacheManager.swift`

```swift
import Foundation

/// Sendable cache manager for reducing API calls
/// TTL: Time-to-live in seconds (default 300 = 5 minutes)
protocol CacheManaging: Sendable {
  func cached<T: Sendable>(
    _ key: String,
    ttl: TimeInterval,
    fetch: () async throws -> T
  ) async throws -> T

  func invalidate(_ key: String)
  func invalidateAll()
}

@MainActor
final class CacheManager: CacheManaging {
  private var cache: [String: CacheEntry] = [:]

  private struct CacheEntry: Sendable {
    let value: Any
    let expiresAt: Date

    var isExpired: Bool {
      Date() > expiresAt
    }
  }

  nonisolated func cached<T: Sendable>(
    _ key: String,
    ttl: TimeInterval,
    fetch: () async throws -> T
  ) async throws -> T {
    // Note: MainActor issue - redesign if needed
    let now = Date()
    if let entry = cache[key], !entry.isExpired,
       let cached = entry.value as? T {
      return cached
    }

    let result = try await fetch()
    cache[key] = CacheEntry(value: result, expiresAt: now.addingTimeInterval(ttl))
    return result
  }

  nonisolated func invalidate(_ key: String) {
    cache.removeValue(forKey: key)
  }

  nonisolated func invalidateAll() {
    cache.removeAll()
  }
}
```

**Step 2: Add to CoachesListViewModel**

```swift
@Observable
@MainActor
final class CoachesListViewModel {
  // ... existing code ...

  private let cacheManager: CacheManaging

  init(
    coachesService: (any CoachesManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    cacheManager: CacheManaging = CacheManager()
  ) {
    self.coachesService = coachesService ?? CoachesServiceImpl(supabaseManager: .shared)
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.cacheManager = cacheManager
  }

  func loadCoaches() async {
    guard let familyUnitId = familyManager.currentMember?.familyUnitId else {
      logger.warning("No familyUnitId available")
      errorMessage = "Unable to load coaches. Please try again."
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      // Cache coaches for 5 minutes (300 seconds)
      let schools = try await cacheManager.cached(
        "schools_\(familyUnitId)",
        ttl: 300
      ) {
        try await coachesService.fetchSchools(familyUnitId: familyUnitId)
      }

      allSchools = schools
      let schoolIds = schools.map(\.id)

      let coaches = try await cacheManager.cached(
        "coaches_\(schoolIds.joined(separator: ","))",
        ttl: 300
      ) {
        try await coachesService.fetchCoaches(schoolIds: schoolIds)
      }

      allCoaches = coaches
      logger.info("Loaded \(coaches.count) coaches")
    } catch {
      logger.error("Failed to load coaches: \(error.localizedDescription)")
      errorMessage = "Failed to load coaches: \(error.localizedDescription)"
    }
  }

  func refreshCoaches() async {
    // Invalidate cache for user-initiated refresh
    cacheManager.invalidateAll()
    await loadCoaches()
  }
}
```

**Step 3: Update View to Call refreshCoaches()**

```swift
.refreshable {
  await viewModel.refreshCoaches()  // Changed from loadCoaches()
}
```

**Step 4: Test**

```swift
func testLoadCoaches_UsesCachedSchools() async {
  let mockCache = MockCacheManager()
  let viewModel = CoachesListViewModel(
    cacheManager: mockCache
  )

  await viewModel.loadCoaches()
  await viewModel.loadCoaches() // Second call

  // Second call should use cache
  XCTAssertEqual(mockCache.cacheHits, 2)
  XCTAssertEqual(mockService.fetchSchoolsCallCount, 1) // Only called once
}
```

---

### 2.2 Add Network Timeouts

**Status:** 🛠️ Medium Effort (2-3 hours)
**Impact:** Better UX on slow connections
**Complexity:** Medium

**File to Modify:**
`/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-ios/TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift`

**Add Timeout Wrapper:**

```swift
// Add at top of SupabaseManager
extension SupabaseManager {
  func withTimeout<T>(_ seconds: TimeInterval, operation: () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await operation()
      }

      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw URLError(.timedOut)
      }

      if let result = try await group.next() {
        group.cancelAll()
        return result
      }

      throw URLError(.timedOut)
    }
  }
}
```

**Apply to Queries:**

```swift
func signIn(email: String, password: String) async throws -> (user: User, session: Session) {
  try await withTimeout(10) {
    let response = try await client.auth.signIn(
      email: email,
      password: password
    )
    // ... rest of implementation
  }
}
```

**Timeout Guidelines:**
- Auth operations: 10 seconds
- List queries: 8 seconds
- Single record fetches: 5 seconds
- Uploads: 30 seconds

---

## Priority 3: Documentation & Architecture (Next Quarter)

### 3.1 Document Model Distribution

**Status:** 📝 Documentation (2 hours)
**Impact:** Prevents duplication as team grows
**Complexity:** Low

**Create File:** `docs/MODEL_ARCHITECTURE.md`

```markdown
# Model Architecture Guide

## Core Models (Shared Across Features)

These models live in `Features/Dashboard/Models/` and are imported by all features:

### Coach
- **Location:** `Features/Dashboard/Models/Coach.swift`
- **Used by:** Coaches, Events, Dashboard, ActivityFeed
- **Codable:** Yes (maps from Supabase)
- **Identifiable:** Yes (conforms to Identifiable)
- **Sendable:** Yes

### School
- **Location:** `Features/Dashboard/Models/School.swift`
- **Used by:** Coaches, Events, Dashboard, Preferences
- **Note:** Single source of truth - do NOT duplicate

### PerformanceMetric
- **Location:** `Features/Performance/Models/PerformanceMetric.swift`
- **Used by:** Events, Performance, Analytics

## Feature-Specific Models

Do NOT move these to shared:
- `CoachFormState` → Coaches/Models (form-specific state)
- `CoachFilters` → Coaches/Models (filtering-specific)
- `OfferFilters` → Offers/Models (offer-specific)

## Rule of Thumb

- **If model used by 2+ features** → Move to Dashboard/Models
- **If model is feature-specific** → Keep in feature folder
- **Always use protocols** → Service APIs, mocking

## When Adding New Core Model

1. Create in `Features/Dashboard/Models/XxxModel.swift`
2. Ensure `Codable`, `Identifiable`, `Sendable`
3. Add to `SHARED_MODELS.md` checklist
4. Update this file
5. Import from Dashboard in all features
```

---

### 3.2 Create Architecture Decision Records (ADRs)

**Status:** 📝 Documentation (3-4 hours)
**Impact:** Onboarding clarity
**Complexity:** Low

**Create File:** `docs/ADR/0001_observable_over_stateobject.md`

```markdown
# ADR-0001: Use @Observable over @StateObject

**Date:** 2026-02-19
**Status:** ACCEPTED
**Deciders:** Team

## Context

SwiftUI has two state management approaches for ViewModels:
1. `@StateObject` with `@Published` (iOS 13+)
2. `@Observable` macro (iOS 17+)

## Decision

Use `@Observable` macro throughout the codebase.

## Rationale

- **Simpler Code:** No `@Published` boilerplate
- **Automatic Tracking:** Tracks accessed properties only (better performance)
- **No Memory Issues:** Doesn't create extra reference cycles
- **Modern:** Aligns with iOS 17+ direction
- **Consistent:** Works cleanly with `@MainActor`

## Implementation

All ViewModels follow this pattern:
```swift
@Observable
@MainActor
final class XxxViewModel {
  var property: Type // No @Published needed

  func action() async { }
}
```

Usage in Views:
```swift
struct XxxView: View {
  @State private var viewModel = XxxViewModel()

  var body: some View {
    // viewModel.property tracked automatically
  }
}
```

## Consequences

- **Positive:** Less code, better performance
- **Negative:** Requires iOS 17+ (acceptable for this project)
- **Risk:** Accidental mutations could bypass SwiftUI tracking (mitigate with tests)

## Related Decisions

- [ADR-0002: Session Fallback Strategy](#adr-0002)
```

**Create File:** `docs/ADR/0002_session_fallback.md`

```markdown
# ADR-0002: Session Fallback Strategy

**Date:** 2026-02-19
**Status:** ACCEPTED

## Context

Supabase sessions can be interrupted by:
- Network failures
- Slow connections
- Token refresh timeouts

The app must handle offline scenarios gracefully.

## Decision

Implement session refresh with fallback:
1. Try to refresh at Supabase
2. If refresh fails, fall back to cached session (if still valid)
3. Only clear session when necessary

## Code

```swift
private func refreshAndSaveSession(fallback: Session?) async {
  do {
    let updatedUser = try await SupabaseManager.shared.refreshSession()
    self.user = updatedUser
    self.isAuthenticated = true
  } catch {
    if let fallback {
      self.session = fallback  // Use cache
      self.isAuthenticated = true
    } else {
      clearSession()  // Clear only when no fallback
    }
  }
}
```

## Consequences

- **Positive:** App works offline for brief periods
- **Positive:** Resilient to transient network errors
- **Negative:** User sees stale data occasionally
- **Mitigation:** Add banner when working offline

## Related

- See `AuthManager.swift:156-179`
```

---

## Implementation Timeline

| Week | Priority | Tasks |
|------|----------|-------|
| **Week 1** | High | Parallelize coaches fetching, Add session buffer |
| **Week 2-3** | Medium | Implement caching layer, Add timeouts |
| **Week 4-5** | Medium | Complete documentation |
| **Quarter 2** | Low | ADRs, consolidate computed properties |

---

## Verification Checklist

After implementing each recommendation, verify:

- [ ] Code compiles without warnings
- [ ] All tests pass
- [ ] New tests added for changed behavior
- [ ] Performance improved (use Instruments)
- [ ] No regressions in accessibility tests
- [ ] Documentation updated
- [ ] Code review approved

---

## Questions & Clarifications

**Q: Should we cache EventDetailViewModel data?**
A: Yes, but differently. Since events change frequently, use shorter TTL (60 seconds) and allow manual refresh.

**Q: Will caching break real-time updates?**
A: Possibly. If Supabase RealtimeService is used, coordinate cache invalidation with real-time updates.

**Q: What if user has slow connection - will timeout break app?**
A: No. Timeouts throw URLError, caught by existing error handling. Show "Slow connection" message to user.

**Q: Should we cache Coach model separately from list?**
A: Yes. When user navigates Coach → CoachDetail, use cached coach from list if available, fetch full details async.

---

## Further Reading

- **Caching Strategies:** See `docs/CACHING_STRATEGY.md` (create when implementing)
- **Performance Profiling:** Use Xcode Instruments: Time Profile, Network
- **Swift Concurrency:** WWDC 2023 "Swift Concurrency in Practice"
