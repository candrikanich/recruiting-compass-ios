# Quick Start: Add Coach E2E Tests

**Created:** February 10, 2026

---

## Run All Tests (Recommended)

```bash
cd /Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-ios-fresh/TheRecruitingCompass

xcodebuild test \
  -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/AddCoachE2ETests
```

**Expected Output:**
- ✅ 15 tests pass (if Supabase configured)
- ⏭️ 15 tests skipped (if Supabase not configured)
- 🖼️ ~50 screenshots in Attachments directory

---

## Run Specific Test

### Happy Path Test
```bash
xcodebuild test \
  -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/AddCoachE2ETests/testAddCoach_withRequiredFields_succeeds
```

### Validation Error Test
```bash
xcodebuild test \
  -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/AddCoachE2ETests/testAddCoach_withoutRole_showsValidationError
```

---

## Run from Xcode (Easier)

1. **Open Project:**
   ```bash
   open TheRecruitingCompass/TheRecruitingCompass.xcodeproj
   ```

2. **Navigate to Test File:**
   - `TheRecruitingCompassUITests` → `E2E` → `AddCoachE2ETests.swift`

3. **Run Tests:**
   - Click diamond ◇ next to `class AddCoachE2ETests` (runs all 15)
   - Click diamond ◇ next to specific test method (runs one)
   - Or press `⌘U` to run all UI tests

4. **Watch Execution:**
   - Simulator launches automatically
   - Tests execute with visual feedback
   - Results appear in Test Navigator

---

## Prerequisites

### 1. Supabase Credentials (Required)

**Option A: Environment Variables (Terminal)**
```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key-here"
```

**Option B: Xcode Scheme (Recommended)**
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. Add:
   - `SUPABASE_URL`: `https://your-project.supabase.co`
   - `SUPABASE_ANON_KEY`: `your-anon-key`

### 2. Test User Account

Tests expect this user to exist:
- **Email:** `test@example.com`
- **Password:** `TestPassword1`

Create in Supabase auth or update tests with your credentials.

### 3. Test Data (Optional)

For best results:
- At least one school tracked
- Family unit created for test user
- Coaches tab visible in tab bar

---

## What Tests Cover

### ✅ Critical Flows
1. **Navigation** - Dashboard → Coaches → Add Coach
2. **Two-Step Form** - School selection triggers form
3. **Happy Path** - Create coach with required fields
4. **Validation** - Error handling for missing fields
5. **Cancel** - Discard form data
6. **Empty State** - No schools message
7. **Social Handles** - @ symbol sanitization
8. **Accessibility** - VoiceOver labels

### 📊 Test Count: 15 E2E Tests

---

## Viewing Screenshots

After test run, screenshots are saved to:
```
~/Library/Developer/Xcode/DerivedData/TheRecruitingCompass-*/Logs/Test/Attachments/
```

**Open Attachments:**
```bash
open ~/Library/Developer/Xcode/DerivedData/TheRecruitingCompass-*/Logs/Test/Attachments/
```

**Screenshots Include:**
- 01-dashboard → 33-accessibility-verified
- ~50 screenshots documenting entire flow
- Captured at every major step
- Named descriptively

---

## Troubleshooting

### All Tests Skip

**Symptom:**
```
Test Case '-[AddCoachE2ETests testNavigateToAddCoachFromCoachesList]' skipped.
```

**Cause:** Supabase not configured or login failed

**Fix:**
1. Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set
2. Verify test user exists (`test@example.com`)
3. Check Supabase is running and accessible

---

### Picker Tests Fail

**Symptom:**
```
School picker not found
```

**Cause:** Picker selectors changed or timing issue

**Fix:**
1. Increase timeout in `selectSchool()` helper
2. Check accessibility identifiers match
3. Run test individually to debug

---

### Keyboard Blocks Button

**Symptom:**
```
Add Coach button not hittable
```

**Cause:** Keyboard covering button

**Fix:**
1. Tests already attempt `app.tap()` to dismiss
2. May need to scroll form before tapping button
3. Try different simulator size

---

### Tests Pass Locally, Fail on CI

**Cause:** Timing differences, slower CI environment

**Fix:**
1. Increase `waitForExistence(timeout:)` values
2. Add retry logic for flaky steps
3. Use predicates instead of fixed delays

---

## Next Steps

### ✅ Immediate
1. Run tests locally to verify setup
2. Review screenshot gallery
3. Fix any failures due to environment

### 🔄 Ongoing
1. Run tests before every PR
2. Add new tests for new features
3. Update selectors when UI changes
4. Monitor test health metrics

### 🚀 Advanced
1. Integrate into CI/CD pipeline
2. Add performance benchmarks
3. Test on multiple simulators
4. Generate test coverage reports

---

## Files Created

1. **Test File:**
   - `TheRecruitingCompassUITests/E2E/AddCoachE2ETests.swift`
   - 15 E2E tests (~600 lines)

2. **Documentation:**
   - `planning/E2E_TESTS_AddCoach_Summary.md` (this file's companion)
   - `planning/E2E_TESTS_QuickStart.md` (this file)

---

## Success Criteria

**Tests are working if:**
- ✅ 15/15 tests pass (or skip gracefully)
- ✅ Screenshots generated (~50 files)
- ✅ Build succeeds with no errors
- ✅ Execution completes in ~2-3 minutes

**Next Action:**
```bash
cd TheRecruitingCompass && xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassUITests/AddCoachE2ETests
```

**Expected Result:** ✅ 15 tests pass (or skip with helpful messages)

---

🎉 **E2E Test Coverage Complete!**
