# Preferences Feature - Quick Test Commands

**After DerivedData is cleaned - run these commands to validate everything**

---

## 1. Verify Build

```bash
cd /Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-ios-fresh/TheRecruitingCompass

xcodebuild clean build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Expected:** `** BUILD SUCCEEDED **`

---

## 2. Run All Tests

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Expected:** `Test Suite 'All tests' passed` with 125+ tests passing

---

## 3. Run Tests with Coverage

```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES \
  -resultBundlePath ./TestResults.xcresult
```

---

## 4. View Coverage Report

```bash
xcrun xccov view --report ./TestResults.xcresult
```

**Target:** >80% coverage on all ViewModels and Services

---

## 5. Run Specific Test Suite

```bash
# Just Preferences tests
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PreferenceServiceTests

# Just Player Details tests
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:TheRecruitingCompassTests/PlayerDetailsViewModelTests
```

---

## Expected Test Results

### PreferenceService Tests
- ✅ 20 tests - All CRUD operations + error handling

### Notification Preferences Tests
- ✅ 12 tests - Toggles, stepper, debouncing, reset

### Home Location Tests
- ✅ 18 tests - Address validation, geocoding, coordinates

### Dashboard Customization Tests
- ✅ 15 tests - Widget toggles, select all, reset

### School Preferences Tests
- ✅ 21 tests - Templates, reorder, dealbreakers, validation

### Player Details Tests
- ✅ 25 tests - Photo upload, validation, role checks, auto-save

**Total:** 111 preference-specific tests (plus 14+ in existing suites)

---

## Success Indicators

✅ Build succeeds (0 errors, 0 warnings)
✅ All tests pass
✅ Coverage >80% on ViewModels
✅ Coverage >85% on PreferenceServiceImpl
✅ No flaky tests (consistent across multiple runs)

---

## If Tests Fail

1. Check the failure message
2. Verify mock setup in test file
3. Check for timing issues (async tests)
4. Re-run individual test to isolate

**Most Common Issues:**
- Timing in async tests (add `await Task.sleep(...)` if needed)
- Mock not configured correctly
- State not reset between tests

---

## Next Steps After Tests Pass

1. ✅ Generate coverage report
2. ✅ Analyze gaps (<80% files)
3. ✅ Write additional tests if needed
4. ✅ Update MEMORY.md with results
5. ✅ Notify team-lead of completion

---

**Ready to go once DerivedData is clean!** 🚀
