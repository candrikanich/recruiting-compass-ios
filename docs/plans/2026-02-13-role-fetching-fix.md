# iOS User Role Fetching Fix - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align iOS app to fetch user role from `public.users` table (matching web app), fixing Family Management access for users who signed up via web.

**Architecture:** Replace User model's computed `role` property with stored property fetched from database. Add retry logic to SupabaseManager for resilient database queries with metadata fallback. Integrate into signIn, refreshSession, and restoreSession flows.

**Tech Stack:** Swift, Supabase Swift SDK, XCTest, OSLog

---

## Task 1: Update User Model Structure

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Models/User.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Models/UserTests.swift` (create new)

**Step 1: Write failing test for User model with stored role**

Create test file:

```swift
// TheRecruitingCompassTests/Core/Models/UserTests.swift
import XCTest
@testable import TheRecruitingCompass

final class UserTests: XCTestCase {
  func testUserDecodesWithRole() throws {
    let json = """
    {
      "id": "123",
      "email": "test@example.com",
      "email_confirmed_at": "2024-01-01T00:00:00Z",
      "phone": null,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "role": "player"
    }
    """.data(using: .utf8)!

    let user = try JSONDecoder().decode(User.self, from: json)

    XCTAssertEqual(user.id, "123")
    XCTAssertEqual(user.email, "test@example.com")
    XCTAssertEqual(user.role, .player)
  }

  func testUserDecodesWithNullRole() throws {
    let json = """
    {
      "id": "123",
      "email": "test@example.com",
      "email_confirmed_at": null,
      "phone": null,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "role": null
    }
    """.data(using: .utf8)!

    let user = try JSONDecoder().decode(User.self, from: json)

    XCTAssertNil(user.role)
  }
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:TheRecruitingCompassTests/UserTests
```

Expected: FAIL - User model doesn't have Codable role property yet

**Step 3: Update User model**

Modify `User.swift`:

```swift
import Foundation

struct User: Codable, Identifiable {
  let id: String
  let email: String
  let emailConfirmedAt: String?
  let phone: String?
  let createdAt: String
  let updatedAt: String
  let role: UserRole?

  enum CodingKeys: String, CodingKey {
    case id
    case email
    case emailConfirmedAt = "email_confirmed_at"
    case phone
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case role
  }
}
```

**Step 4: Run test to verify it passes**

Run:
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:TheRecruitingCompassTests/UserTests
```

Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Models/User.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Models/UserTests.swift
git commit -m "refactor: replace User computed role with stored property"
```

---

## Task 2: Add DatabaseUser Struct to SupabaseManager

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift:1-150`

**Step 1: Add DatabaseUser struct and logger**

Add near top of `SupabaseManager.swift` after imports:

```swift
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "UserProfile"
)

// Add inside SupabaseManager class, before methods
private struct DatabaseUser: Codable {
  let id: String
  let email: String
  let full_name: String?
  let role: String
  let created_at: String
  let updated_at: String
}
```

**Step 2: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift
git commit -m "feat: add DatabaseUser struct and logger to SupabaseManager"
```

---

## Task 3: Add fetchUserProfile Method

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift`
- Test: `TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/SupabaseManagerTests.swift` (create new)

**Step 1: Write failing test**

Create test file:

```swift
// TheRecruitingCompassTests/Core/Services/SupabaseManagerTests.swift
import XCTest
@testable import TheRecruitingCompass

final class SupabaseManagerTests: XCTestCase {
  // Note: This is a placeholder test since we can't easily mock Supabase client
  // Real testing will be done in integration tests

  func testFetchUserProfileMethodExists() {
    let manager = SupabaseManager.shared
    // Verify method signature exists (compile-time check)
    XCTAssertNotNil(manager.client)
  }
}
```

**Step 2: Run test to verify it passes (placeholder)**

Run:
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:TheRecruitingCompassTests/SupabaseManagerTests
```

Expected: PASS

**Step 3: Implement fetchUserProfile method**

Add to `SupabaseManager` class:

```swift
func fetchUserProfile(userId: String) async throws -> User {
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

**Step 4: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift \
        TheRecruitingCompass/TheRecruitingCompassTests/Core/Services/SupabaseManagerTests.swift
git commit -m "feat: add fetchUserProfile method to SupabaseManager"
```

---

## Task 4: Add Retry Logic with Metadata Fallback

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift`

**Step 1: Add createUserFromMetadata helper**

Add to `SupabaseManager` class:

```swift
private func createUserFromMetadata(
  userId: String,
  email: String,
  metadata: [String: AnyJSON]?
) -> User? {
  guard let metadata = metadata,
        let roleData = metadata["role"],
        case let roleString as String = roleData.value,
        let role = UserRole(rawValue: roleString) else {
    return nil
  }

  return User(
    id: userId,
    email: email,
    emailConfirmedAt: nil,
    phone: nil,
    createdAt: ISO8601DateFormatter().string(from: Date()),
    updatedAt: ISO8601DateFormatter().string(from: Date()),
    role: role
  )
}
```

**Step 2: Add fetchUserProfileWithRetry method**

Add to `SupabaseManager` class:

```swift
func fetchUserProfileWithRetry(
  userId: String,
  email: String,
  fallbackMetadata: [String: AnyJSON]?
) async -> User? {
  let maxRetries = 3
  let retryDelays: [UInt64] = [500_000_000, 1_000_000_000, 2_000_000_000]

  for attempt in 0..<maxRetries {
    do {
      let user = try await fetchUserProfile(userId: userId)
      logger.info("Successfully fetched user profile for \(userId)")
      return user
    } catch {
      logger.warning("Attempt \(attempt + 1)/\(maxRetries) failed: \(error.localizedDescription)")
      if attempt < maxRetries - 1 {
        try? await Task.sleep(nanoseconds: retryDelays[attempt])
      }
    }
  }

  // Fallback to metadata if all retries failed
  logger.error("All retries failed for user \(userId), falling back to metadata")
  return createUserFromMetadata(userId: userId, email: email, metadata: fallbackMetadata)
}
```

**Step 3: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift
git commit -m "feat: add retry logic with metadata fallback"
```

---

## Task 5: Update signIn Method

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift:19-29`

**Step 1: Update signIn to use fetchUserProfileWithRetry**

Replace existing `signIn` method:

```swift
func signIn(email: String, password: String) async throws -> (user: User, session: Session) {
  let response = try await client.auth.signIn(
    email: email,
    password: password
  )

  // Fetch user profile from database with retry
  guard let user = await fetchUserProfileWithRetry(
    userId: response.user.id.uuidString,
    email: response.user.email ?? email,
    fallbackMetadata: response.user.userMetadata
  ) else {
    throw AuthError.serverError("Failed to fetch user profile")
  }

  let session = mapToSession(response, user: user)

  return (user, session)
}
```

**Step 2: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift
git commit -m "refactor: update signIn to fetch role from database"
```

---

## Task 6: Update signUp Method

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift:31-57`

**Step 1: Update signUp to use fetchUserProfileWithRetry**

Replace existing `signUp` method:

```swift
func signUp(
  email: String,
  password: String,
  fullName: String,
  role: UserRole,
  familyCode: String?
) async throws -> (user: User, session: Session?) {
  var metadata: [String: AnyJSON] = [
    "full_name": .string(fullName),
    "role": .string(role.rawValue)
  ]

  if let familyCode = familyCode, !familyCode.trimmingCharacters(in: .whitespaces).isEmpty {
    metadata["family_code"] = .string(familyCode)
  }

  let response = try await client.auth.signUp(
    email: email,
    password: password,
    data: metadata
  )

  // Try to fetch from database, fall back to metadata for new users
  let user = await fetchUserProfileWithRetry(
    userId: response.user.id.uuidString,
    email: response.user.email ?? email,
    fallbackMetadata: response.user.userMetadata
  ) ?? User(
    id: response.user.id.uuidString,
    email: response.user.email ?? email,
    emailConfirmedAt: nil,
    phone: nil,
    createdAt: ISO8601DateFormatter().string(from: Date()),
    updatedAt: ISO8601DateFormatter().string(from: Date()),
    role: role
  )

  let session = response.session.map { mapToSession($0, user: user) }

  return (user, session)
}
```

**Step 2: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift
git commit -m "refactor: update signUp to fetch role from database"
```

---

## Task 7: Update refreshSession Method

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift:77-85`

**Step 1: Update refreshSession to fetch from database**

Replace existing `refreshSession` method:

```swift
func refreshSession() async throws -> User {
  let authSession = try await client.auth.session

  guard let user = await fetchUserProfileWithRetry(
    userId: authSession.user.id.uuidString,
    email: authSession.user.email ?? "",
    fallbackMetadata: authSession.user.userMetadata
  ) else {
    throw AuthError.serverError("Failed to fetch user profile")
  }

  return user
}
```

**Step 2: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift
git commit -m "refactor: update refreshSession to fetch role from database"
```

---

## Task 8: Remove Old mapToUser Method

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift:127-142`

**Step 1: Remove mapToUser helper (no longer needed)**

Delete the `mapToUser` method from SupabaseManager since we now fetch User directly from database:

```swift
// DELETE THIS METHOD:
// private func mapToUser(_ authUser: Supabase.User) -> User { ... }
```

**Step 2: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/SupabaseManager.swift
git commit -m "refactor: remove mapToUser helper (replaced by fetchUserProfile)"
```

---

## Task 9: Update AuthManager restoreSession

**Files:**
- Modify: `TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift:130-178`

**Step 1: Update restoreSession to refresh user profile**

Replace the `restoreSession` method:

```swift
func restoreSession() async {
  isCheckingSession = true
  defer { isCheckingSession = false }

  do {
    // Try to load session from Keychain
    let savedSession: Session = try keychain.load(Session.self, forKey: sessionKey)

    // Check if session is expired
    let now = Int(Date().timeIntervalSince1970)
    if savedSession.expiresAt > now {
      // Session is still valid - refresh to get latest user data
      do {
        let updatedUser = try await SupabaseManager.shared.refreshSession()
        // If refresh succeeds, get the new session
        if let newSession = try await SupabaseManager.shared.getCurrentSession() {
          self.session = newSession
          self.user = updatedUser
          self.isAuthenticated = true
          self.errorMessage = nil
          try keychain.save(newSession, forKey: sessionKey)
        } else {
          // No session after refresh, clear everything
          self.session = nil
          self.user = nil
          self.isAuthenticated = false
          try keychain.delete(forKey: sessionKey)
        }
      } catch {
        // Refresh failed, but session is still valid - use cached data
        self.session = savedSession
        self.user = savedSession.user
        self.isAuthenticated = true
      }
    } else {
      // Session expired, try to refresh
      do {
        let updatedUser = try await SupabaseManager.shared.refreshSession()
        if let newSession = try await SupabaseManager.shared.getCurrentSession() {
          self.session = newSession
          self.user = updatedUser
          self.isAuthenticated = true
          self.errorMessage = nil
          try keychain.save(newSession, forKey: sessionKey)
        } else {
          self.session = nil
          self.user = nil
          self.isAuthenticated = false
          try keychain.delete(forKey: sessionKey)
        }
      } catch {
        // Refresh failed, clear stored session
        self.session = nil
        self.user = nil
        self.isAuthenticated = false
        try? keychain.delete(forKey: sessionKey)
      }
    }
  } catch {
    // No saved session found
    self.isAuthenticated = false
    self.session = nil
    self.user = nil
  }
}
```

**Step 2: Verify build**

Run:
```bash
xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TheRecruitingCompass/TheRecruitingCompass/Core/Services/AuthManager.swift
git commit -m "refactor: update restoreSession to fetch fresh user profile"
```

---

## Task 10: Run All Tests

**Files:**
- None (verification step)

**Step 1: Run full test suite**

Run:
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: All tests pass (126+ tests)

**Step 2: Fix any broken tests**

If tests fail, review error messages and update tests that relied on old User model structure (specifically tests checking `userMetadata`).

Common fixes:
- Remove tests that checked `user.role` computed from `userMetadata`
- Update mock User objects to use stored `role` property

**Step 3: Re-run tests after fixes**

Run:
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: All tests pass

**Step 4: Commit any test fixes**

```bash
git add TheRecruitingCompass/TheRecruitingCompassTests/
git commit -m "test: update tests for new User model structure"
```

---

## Task 11: Manual Testing - Login Flow

**Files:**
- None (manual testing)

**Step 1: Clean build and run**

```bash
xcodebuild clean build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Step 2: Launch app in simulator**

```bash
xcrun simctl boot "iPhone 15"
open -a Simulator
# Then run the app from Xcode
```

**Step 3: Test login with test.player2028@andrikanich.com**

1. Launch app
2. Tap "Login"
3. Enter credentials:
   - Email: `test.player2028@andrikanich.com`
   - Password: (use actual test password)
4. Tap "Sign In"

**Expected:**
- Login succeeds
- Redirects to Dashboard
- Console logs show: "Successfully fetched user profile for [userId]"

**Step 4: Navigate to Family Management**

1. From Dashboard, navigate to Settings
2. Tap "Family Management"

**Expected:**
- ✅ Family Management screen shows content (NOT "unavailable" message)
- ✅ Shows family code: FAM-DF387A
- ✅ Shows 3 family members (Test Player, Chris Andrikanich, Test Parent2)

**Step 5: Document results**

If successful, note in plan:
```
✅ Manual test passed - test.player2028@andrikanich.com sees Family Management
```

If failed, debug:
- Check console logs for errors
- Verify database connection
- Check retry/fallback logs

---

## Task 12: Manual Testing - Session Restore

**Files:**
- None (manual testing)

**Step 1: Stay logged in and close app**

1. With user still logged in from Task 11
2. Swipe up from bottom to go home
3. Swipe up again to see app switcher
4. Swipe up on Recruiting Compass to kill app

**Step 2: Re-launch app**

1. Tap app icon to launch fresh
2. App should restore session automatically

**Expected:**
- ✅ App opens directly to Dashboard (no login screen)
- ✅ Console logs show: "Successfully fetched user profile"
- ✅ Family Management still works

**Step 3: Test airplane mode fallback**

1. Enable Airplane Mode on simulator
2. Kill and re-launch app

**Expected:**
- ✅ App still opens to Dashboard
- ✅ Console logs show: "All retries failed... falling back to metadata"
- ✅ Family Management still works (using cached session)

**Step 4: Disable airplane mode and re-launch**

1. Disable Airplane Mode
2. Kill and re-launch app

**Expected:**
- ✅ Console logs show: "Successfully fetched user profile"
- ✅ Database fetch resumes normally

---

## Task 13: Code Review & Cleanup

**Files:**
- Review all modified files

**Step 1: Review code quality**

Check:
- ✅ No hardcoded strings or magic numbers
- ✅ All methods have proper error handling
- ✅ Logging is comprehensive but not excessive
- ✅ Code follows existing patterns in codebase

**Step 2: Review tests**

Check:
- ✅ Unit tests cover happy path
- ✅ Tests cover error scenarios
- ✅ Test names are descriptive

**Step 3: Update documentation if needed**

If any public API changed, update:
- Code comments
- README if necessary

**Step 4: Final commit**

```bash
git add -A
git commit -m "docs: update code comments for role fetching changes"
```

---

## Task 14: Create Pull Request

**Files:**
- None (git operations)

**Step 1: Push branch**

```bash
git push -u origin fix/ios-role-fetching
```

**Step 2: Create PR via GitHub CLI**

```bash
gh pr create --title "fix: align iOS role fetching with web app" --body "$(cat <<'EOF'
## Summary
- Fixes Family Management showing "unavailable" for users who signed up via web
- Aligns iOS app to fetch user role from `public.users` table (matching web app)
- Adds retry logic with metadata fallback for resilience

## Changes
- Updated User model to use stored `role` property instead of computed
- Added `fetchUserProfile()` and `fetchUserProfileWithRetry()` to SupabaseManager
- Updated signIn, signUp, refreshSession to fetch from database
- Updated restoreSession to refresh user profile on app launch

## Testing
- ✅ All unit tests pass (126+)
- ✅ Manual test: test.player2028@andrikanich.com sees Family Management
- ✅ Session restore works with network enabled/disabled
- ✅ Retry and fallback logic verified

## References
- Design Doc: docs/plans/2026-02-13-role-fetching-fix-design.md
- Root Cause: Investigation on 2026-02-13

Fixes #[issue-number]
EOF
)"
```

**Expected:** PR created successfully with URL

---

## Success Criteria Checklist

Before merging, verify:

- ✅ All tests pass
- ✅ `test.player2028@andrikanich.com` sees Family Management on iOS
- ✅ Family Management shows correct data (family code, 3 members)
- ✅ Login works with database fetch
- ✅ Session restore refreshes user profile
- ✅ Retry logic works (tested with network issues)
- ✅ Fallback to metadata works (backward compatible)
- ✅ No regression in existing functionality

---

## Rollback Plan

If critical issues discovered after merge:

1. Revert PR immediately:
   ```bash
   git revert <commit-hash>
   git push
   ```

2. Investigate issue in separate branch

3. Users can still log in via metadata fallback during investigation

---

## Post-Deployment Monitoring

After merge, monitor:

1. **Logs:** Check for fallback usage
   - Search for: "falling back to metadata"
   - High fallback rate indicates database query issues

2. **User feedback:** Family Management access working

3. **Crash reports:** No new crashes related to User model or auth

4. **Performance:** Database query doesn't slow down login significantly

---

## References

- **Design Document:** `docs/plans/2026-02-13-role-fetching-fix-design.md`
- **Web App Implementation:** `/Volumes/AlphabetSoup/TheRecruitingCompass/code/recruiting-compass-web/stores/user.ts`
- **Database Schema:** `public.users` table
- **TDD Skill:** @superpowers:test-driven-development
- **Verification Skill:** @superpowers:verification-before-completion
