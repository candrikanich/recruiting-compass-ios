# E2E Test Plan: Signup & Email Verification

**Date:** 2026-02-07
**Status:** Approved
**Scope:** Comprehensive E2E testing for signup feature production readiness

---

## Architecture Decision

This is a **native iOS SwiftUI app**. Playwright is designed for browser-based testing and cannot interact with iOS simulator UIs. The correct approach is:

### Layer 1: XCUITest (iOS Simulator E2E)
- Tests the actual UI in the iOS Simulator via XCUITest (Apple's native UI testing framework)
- Validates the full user journey: Landing -> Role Selection -> Signup Form -> Email Verification -> Dashboard
- Already has a UITests target scaffolded in the Xcode project

### Layer 2: Supabase API Integration Tests (TypeScript + Playwright Test Runner)
- Uses `@playwright/test` as a **test runner only** (no browser needed)
- Tests Supabase Auth API directly: signup, email verification, session management, duplicate detection
- Validates backend behavior independent of the iOS UI
- Runs in CI/CD without needing macOS or Xcode

---

## Test Scenarios

### Scenario 1: Parent Signup Flow (XCUITest)
1. Launch app -> Landing screen visible
2. Tap "Create Account" -> Navigate to SignupView
3. Verify role selection screen with 3 roles (Parent, Student, Player)
4. Select "Parent" role -> Form appears
5. Fill Full Name, Email (unique), Password, Confirm Password
6. Accept terms checkbox
7. Tap "Create Account"
8. Verify navigation to Email Verification screen
9. Verify polling state indicators

### Scenario 2: Student Signup with Family Code (API test)
1. Create parent account via API
2. Extract family_code from user_metadata
3. Create student account with family_code
4. Verify family_code stored in student's user_metadata

### Scenario 3: Error Scenarios (XCUITest + API)
- Duplicate email -> "Already registered" error
- Invalid family code format -> Validation error
- Weak password -> Real-time strength indicator
- Password mismatch -> Error message
- Empty required fields -> Validation errors

### Scenario 4: Session Persistence (XCUITest)
- Complete signup -> verify dashboard
- Terminate and relaunch app
- Verify auto-login (no login screen)

### Scenario 5: Email Verification Polling (XCUITest + API)
- Verify initial "pending" state
- Verify "checking" transition
- Test resend with 60s cooldown
- Verify verified state shows "Continue to Dashboard"

---

## File Structure

```
TheRecruitingCompassUITests/
  E2E/
    SignupFlowE2ETests.swift          # Full parent signup flow
    SignupValidationE2ETests.swift    # Form validation scenarios
    SignupSessionPersistenceTests.swift # Session restore after relaunch
    EmailVerificationE2ETests.swift   # Polling and verification states

e2e-api-tests/                        # API-level integration tests
  package.json
  tsconfig.json
  playwright.config.ts
  tests/
    signup-api.spec.ts                # Supabase signup API tests
    email-verification-api.spec.ts   # Email verification API tests
    session-management-api.spec.ts   # Session token management
    family-code-api.spec.ts          # Family code validation
  helpers/
    supabase-client.ts               # Supabase admin client
    test-data.ts                     # Unique email generators
    cleanup.ts                       # Test data cleanup
  README.md
```

---

## Environment Variables

- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous key
- `SUPABASE_SERVICE_ROLE_KEY` - For admin operations (email verification, cleanup)

---

## Unresolved Questions

None - all requirements are clear from the codebase analysis.
