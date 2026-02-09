# E2E Test Failures Investigation Report

**Date:** February 9, 2026
**Session:** E2E Test Debugging
**Status:** Partially Fixed - Needs Xcode Debugging

---

## 🎯 Executive Summary

21 E2E tests are failing due to accessibility changes made in Session 4. The root cause has been identified and element query fixes have been applied, but tests still fail during setup/navigation. **Xcode debugging required** to identify exact assertion failures.

---

## 📊 Test Results

| Test Suite | Passing | Failing | Notes |
|------------|---------|---------|-------|
| SignupFlowE2ETests | 6 | 4 | Navigation tests pass, form tests fail |
| SignupValidationE2ETests | 0 | 10 | All fail during setup |
| EmailVerificationE2ETests | 0 | 5 | All fail |
| PasswordResetE2ETests | 5 | 5 | Mixed results |
| **Total** | **11** | **21** | **~34% pass rate** |

---

## 🔍 Root Cause

### What Happened in Session 4

**Phase 2 Accessibility Work** improved VoiceOver experience by using:
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Combined label")
```

**Impact on Tests:**
- Changed element types from `staticTexts` to combined accessibility elements
- E2E tests queried wrong element types
- All queries for `app.staticTexts.matching(...)` broke

### Example: Password Strength Indicator

**Before Session 4:**
```swift
// Component
Text("Weak")
  .accessibilityLabel("Password strength: Weak")
// Query
app.staticTexts.matching(
  NSPredicate(format: "label CONTAINS 'Password strength: Weak'")
).firstMatch
```

**After Session 4:**
```swift
// Component (combined element)
HStack {
  Text("Strength")
  Text("Weak")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Password strength: Weak")

// Query (BROKEN)
app.staticTexts.matching(...) // ❌ Not a staticText anymore!
```

---

## ✅ Fixes Applied

### 1. SignupScreenObject.swift (8 queries fixed)

Changed element queries to work with combined accessibility elements:

```swift
// BEFORE
var passwordStrengthWeak: XCUIElement {
  app.staticTexts.matching(
    NSPredicate(format: "label CONTAINS 'Password strength: Weak'")
  ).firstMatch
}

// AFTER
var passwordStrengthWeak: XCUIElement {
  // Use descendants(matching: .any) to find combined accessibility elements
  app.descendants(matching: .any).matching(
    NSPredicate(format: "label CONTAINS 'Password strength: Weak'")
  ).firstMatch
}
```

**Fixed Elements:**
- `passwordStrengthWeak`
- `passwordStrengthFair`
- `passwordStrengthStrong`
- `errorBanner(containing:)`
- `verifyYourEmailHeadline`
- `verifiedHeadline`
- `resendCooldownText`
- `dashboardWelcomeText`

### 2. SignupFlowE2ETests.swift (1 query fixed)

Fixed error checking in `testFullParentSignupFlow`:
```swift
// Changed from app.staticTexts to app.descendants(matching: .any)
let errorExists = app.descendants(matching: .any).matching(
  NSPredicate(format: "label CONTAINS[cd] 'error' OR label CONTAINS[cd] 'failed'")
).firstMatch.exists
```

### 3. EmailVerificationE2ETests.swift (2 queries fixed)

Fixed verification text queries:
```swift
// testVerificationScreenShowsPendingState
let sentEmailText = app.descendants(matching: .any).matching(
  NSPredicate(format: "label CONTAINS[cd] 'verification link'")
).firstMatch

// testVerificationPollingShowsCheckingState
let checkingLabel = app.descendants(matching: .any).matching(
  NSPredicate(format: "label CONTAINS[cd] 'Checking'")
).firstMatch
```

---

## ❌ Why Tests Still Fail

### Hypothesis

Tests are failing **before** reaching the password strength/element queries. Likely failing during:
1. **Test Setup** - Navigation to signup form
2. **Role Selection** - Tapping role cards
3. **Form Appearance** - Waiting for form fields

### Evidence

- `testAllThreeRolesVisible` **passes** (only checks role cards exist)
- All `SignupValidationE2ETests` **fail** (setup navigates to form)
- Setup timeout is only **5 seconds** - may not be enough

### Cannot Confirm Without Xcode

CLI debugging limitations:
- ❌ No access to assertion failure messages
- ❌ XCTest print statements don't show in xcodebuild output
- ❌ Can't set breakpoints
- ❌ Can't inspect element hierarchy visually

---

## 🛠 Next Steps (When Opening Xcode)

### 1. Run Failing Test with Breakpoint (5 min)

```swift
// Set breakpoint in SignupValidationE2ETests.swift
override func setUpWithError() throws {
  // ... setup code ...

  screen.navigateToSignup()
  screen.selectRole(.parent)
  XCTAssertTrue(screen.fullNameField.waitForExistence(timeout: 5)) // <- Breakpoint here
}
```

**Check:**
- Does navigation succeed?
- Does role selection succeed?
- Does fullNameField exist?
- What's the actual error message?

### 2. Inspect Element Hierarchy (5 min)

In Xcode UI Test debugger:
```swift
po app.buttons.allElementsBoundByIndex.map { $0.label }
po app.textFields.allElementsBoundByIndex.map { $0.label }
```

**Verify:**
- Are role cards visible?
- Are form fields accessible?
- Do labels match expectations?

### 3. Increase Timeouts if Needed (2 min)

If navigation is slow:
```swift
// In setUpWithError
XCTAssertTrue(screen.fullNameField.waitForExistence(timeout: 10)) // 5 → 10
```

### 4. Add Accessibility Identifiers (Optional, 30 min)

Most robust long-term solution:
```swift
// In PasswordStrengthIndicator.swift
.accessibilityIdentifier("passwordStrengthIndicator")

// In test
let indicator = app.otherElements["passwordStrengthIndicator"]
```

**Benefits:**
- No dependency on labels/text
- Works with localization
- More stable across UI changes

---

## 📁 Modified Files

Keep these changes:
- ✅ `TheRecruitingCompassUITests/Helpers/SignupScreenObject.swift`
- ✅ `TheRecruitingCompassUITests/E2E/SignupFlowE2ETests.swift`
- ✅ `TheRecruitingCompassUITests/E2E/EmailVerificationE2ETests.swift`

---

## 💡 Recommendations

### Immediate (This Session)
1. **Commit the fixes** we made to SignupScreenObject
2. **Mark E2E tests as TODO** - Create ticket/issue
3. **Continue development** - Unit tests (538) all pass

### Next Session (With Xcode)
1. **Debug one failing test** with breakpoints (15 min)
2. **Fix root cause** once identified (15-30 min)
3. **Run full E2E suite** to verify all tests pass

### Long-Term (Optional)
1. **Add accessibility identifiers** to all tested components
2. **Reduce test flakiness** with better waits
3. **Consider Vercel Agent Browser** for E2E (mentioned in skills)

---

## 🎓 Lessons Learned

1. **Accessibility changes affect tests** - Always run E2E after a11y work
2. **Combined elements need different queries** - Use `descendants(matching: .any)`
3. **CLI debugging has limits** - Some issues need Xcode
4. **Unit tests > E2E tests** - 538 unit tests provide good coverage

---

## ✅ Success Criteria

Tests will be considered **fixed** when:
- [ ] All `SignupValidationE2ETests` pass (10 tests)
- [ ] All `EmailVerificationE2ETests` pass (5 tests)
- [ ] All `PasswordResetE2ETests` pass (10 tests)
- [ ] All `SignupFlowE2ETests` pass (10 tests)
- [ ] **Total: 35 tests passing**

---

**Status:** Ready for Xcode debugging session
**Estimated Time to Fix:** 30-45 minutes with Xcode
**Blocking:** No - unit tests pass, development can continue
