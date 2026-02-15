# iOS User Role Fetching Fix - Design Document

**Date:** 2026-02-13
**Author:** Claude Code
**Status:** Approved

---

## Problem Statement

The iOS app and web app show different Family Management experiences for the same user (`test.player2028@andrikanich.com`) despite sharing the same Supabase database.

**Root Cause:**
- **Web app** reads user role from `public.users.role` (custom database table)
- **iOS app** reads user role from `auth.users.user_metadata.role` (auth metadata)

When users sign up via the web app, their role is stored in `public.users` but NOT in `user_metadata`, causing the iOS app to see no role and show "Family Management Unavailable."

---

## Solution Overview

Align the iOS app to fetch user role from the `public.users` table (matching web app behavior), making the database the single source of truth for user roles.

---

## Design Decisions

### 1. When to Fetch Role
**Decision:** Fetch during session restore (app launch)

**Rationale:**
- Ensures role is fresh when app starts
- Doesn't require database call on every role check
- Matches web app's `initializeUser()` pattern

### 2. Error Handling
**Decision:** Retry with exponential backoff, then fall back to metadata

**Retry Strategy:**
- 3 attempts with delays: 0.5s, 1s, 2s
- Falls back to `user_metadata.role` if all retries fail
- Ensures users aren't blocked by transient network issues

### 3. User Model Structure
**Decision:** Replace computed `role` property with stored property

**Rationale:**
- Matches web app's User model
- Role comes from one authoritative source
- Cleaner model without complex computed properties
- Removes need for `userMetadata` field

---

## Architecture Changes

### User Model Changes

**Before:**
```swift
struct User: Codable, Identifiable {
  let id: String
  let email: String
  let userMetadata: [String: AnyCodable]?

  var role: UserRole? {  // Computed property
    // Complex parsing from userMetadata
  }
}
```

**After:**
```swift
struct User: Codable, Identifiable {
  let id: String
  let email: String
  let emailConfirmedAt: String?
  let phone: String?
  let createdAt: String
  let updatedAt: String
  let role: UserRole?  // Stored property from database
}
```

---

### SupabaseManager Changes

**New Method: `fetchUserProfile(userId:)`**

Queries `public.users` table to fetch complete user profile:

```swift
func fetchUserProfile(userId: String) async throws -> User {
  struct DatabaseUser: Codable {
    let id: String
    let email: String
    let full_name: String?
    let role: String
    let created_at: String
    let updated_at: String
  }

  let dbUser: DatabaseUser = try await client
    .from("users")
    .select()
    .eq("id", value: userId)
    .single()
    .execute()
    .value

  return User(
    id: dbUser.id,
    email: dbUser.email,
    emailConfirmedAt: nil,
    phone: nil,
    createdAt: dbUser.created_at,
    updatedAt: dbUser.updated_at,
    role: UserRole(rawValue: dbUser.role)
  )
}
```

**New Method: `fetchUserProfileWithRetry(userId:fallbackMetadata:)`**

Implements retry logic with fallback to metadata:

```swift
func fetchUserProfileWithRetry(
  userId: String,
  fallbackMetadata: [String: AnyJSON]?
) async -> User? {
  let maxRetries = 3
  let retryDelays: [UInt64] = [500_000_000, 1_000_000_000, 2_000_000_000]

  for attempt in 0..<maxRetries {
    do {
      return try await fetchUserProfile(userId: userId)
    } catch {
      logger.warning("Attempt \(attempt + 1) failed: \(error)")
      if attempt < maxRetries - 1 {
        try? await Task.sleep(nanoseconds: retryDelays[attempt])
      }
    }
  }

  // Fallback to metadata if all retries failed
  logger.error("All retries failed, using metadata fallback")
  return createUserFromMetadata(userId: userId, metadata: fallbackMetadata)
}
```

---

### Integration Points

**1. signIn() Flow**

```swift
func signIn(email: String, password: String) async throws -> (user: User, session: Session) {
  // Authenticate
  let response = try await client.auth.signIn(email: email, password: password)

  // Fetch profile from database
  guard let user = await fetchUserProfileWithRetry(
    userId: response.user.id.uuidString,
    fallbackMetadata: response.user.userMetadata
  ) else {
    throw AuthError.serverError("Failed to fetch user profile")
  }

  // Create session
  let session = mapToSession(response, user: user)
  return (user, session)
}
```

**2. refreshSession() Flow**

```swift
func refreshSession() async throws -> User {
  let authSession = try await client.auth.session

  guard let user = await fetchUserProfileWithRetry(
    userId: authSession.user.id.uuidString,
    fallbackMetadata: authSession.user.userMetadata
  ) else {
    throw AuthError.serverError("Failed to fetch user profile")
  }

  return user
}
```

**3. restoreSession() in AuthManager**

```swift
func restoreSession() async {
  // Load session from Keychain
  let savedSession: Session = try keychain.load(Session.self, forKey: sessionKey)

  // Refresh to get latest role
  if savedSession.expiresAt > now {
    do {
      let updatedUser = try await SupabaseManager.shared.refreshSession()
      self.user = updatedUser
      self.isAuthenticated = true
    } catch {
      // Fallback to cached session
      self.user = savedSession.user
      self.isAuthenticated = true
    }
  }
}
```

---

## Error Handling

### Logging Strategy

Use structured logging with OSLog:

```swift
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "UserProfile"
)
```

**Log Events:**
- ✅ Successful profile fetch
- ⚠️ Retry attempts
- ❌ Fallback to metadata
- 🚨 Complete failure

### Error Scenarios

| Scenario | Handling |
|----------|----------|
| Network failure | Retry 3x with exponential backoff |
| User not in `public.users` | Fall back to metadata (legacy users) |
| Invalid role value | Log error, set role to `nil` |
| Complete failure | Throw error, prevent authentication |

---

## Testing Strategy

### Unit Tests

**SupabaseManagerTests:**
- ✅ `fetchUserProfile` with valid response
- ✅ Retry logic with simulated network failures
- ✅ Fallback to metadata when database unavailable
- ✅ Error handling for missing user

**AuthManagerTests:**
- ✅ Login flow fetches role from database
- ✅ Session restore refreshes profile
- ✅ Fallback works with mock failures

### Integration Tests

- ✅ End-to-end login → database fetch → session creation
- ✅ Session restore with stale cached user
- ✅ Network failure scenarios

### Manual Testing

- ✅ Verify `test.player2028@andrikanich.com` sees Family Management
- ✅ Test with airplane mode (network disabled)
- ✅ Fresh login vs. session restore paths

---

## Migration Considerations

### Existing Users

**Users with metadata role only:**
- First login: Fallback to metadata works
- Background: Web app creates `public.users` entry
- Subsequent logins: Fetch from database

**Users with database role:**
- Works immediately after deployment

### Backward Compatibility

- Fallback to metadata ensures no user is blocked
- Gradual migration as users log in
- No database migration required

---

## Success Criteria

✅ **Primary Goal:**
`test.player2028@andrikanich.com` sees Family Management on iOS (matches web app)

✅ **Secondary Goals:**
- All role checks use database as source of truth
- Retry logic handles transient failures gracefully
- Existing users can still log in (backward compatible)
- Tests cover happy path + error scenarios

---

## Implementation Phases

**Phase 1: User Model & SupabaseManager**
- Update User model (remove computed role, add stored property)
- Add `fetchUserProfile()` and `fetchUserProfileWithRetry()` to SupabaseManager
- Write unit tests

**Phase 2: Integration**
- Update `signIn()` to fetch from database
- Update `refreshSession()` to fetch from database
- Update `restoreSession()` in AuthManager
- Write integration tests

**Phase 3: Testing & Validation**
- Manual testing with test user
- Network failure scenarios
- Verify backward compatibility

**Phase 4: Deployment**
- Merge to main
- Monitor logs for any fallback usage
- Verify production metrics

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Database query failure blocks login | Retry logic + fallback to metadata |
| Legacy users only have metadata | Fallback ensures they can still log in |
| Performance impact of database query | Query is simple (single row by PK), cached during session |
| Role changes not reflected | Session restore on app launch refreshes role |

---

## References

- **Root Cause Analysis:** Investigation on 2026-02-13
- **Web App Implementation:** `stores/user.ts` (lines 95-112)
- **iOS Current Implementation:** `Core/Models/User.swift` (lines 22-29)
- **Database Schema:** `public.users` table with `role` column
