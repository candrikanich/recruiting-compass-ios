# Preferences Feature - Test Coverage Analysis Plan

**Date:** February 12, 2026
**Task:** #7 - Unit Test Validation
**Target:** 80%+ coverage across all ViewModels and Services
**Status:** Ready to execute (pending build fix)

---

## Test Inventory

### Existing Tests (125+ total)

#### PreferenceService Tests (20 tests)
**File:** `PreferenceServiceTests.swift`
- ✅ Fetch preferences (success/error)
- ✅ Save preferences (success/error)
- ✅ Delete preferences
- ✅ Error handling
- ✅ JSONB encoding/decoding

#### Notification Preferences Tests (12 tests)
**File:** `NotificationPreferencesViewModelTests.swift`
- ✅ Load settings
- ✅ Save settings
- ✅ Toggle changes
- ✅ Stepper updates
- ✅ Reset to defaults
- ✅ Auto-save debouncing

#### Home Location Tests (18 tests)
**File:** `HomeLocationViewModelTests.swift`
- ✅ Load location
- ✅ Save location
- ✅ Address geocoding
- ✅ Coordinate validation
- ✅ Error handling

#### Dashboard Customization Tests (15 tests)
**File:** `DashboardCustomizationViewModelTests.swift`
- ✅ Load widget visibility
- ✅ Save changes
- ✅ Toggle stats cards
- ✅ Toggle widgets
- ✅ Select all/Deselect all
- ✅ Reset to defaults

#### School Preferences Tests (21 tests)
**File:** `SchoolPreferencesViewModelTests.swift`
- ✅ Load preferences
- ✅ Save preferences
- ✅ Add preference
- ✅ Remove preference
- ✅ Reorder (drag-to-reorder)
- ✅ Apply templates
- ✅ Toggle dealbreaker
- ✅ Validation

#### Player Details Tests (25 tests)
**File:** `PlayerDetailsViewModelTests.swift`
- ✅ Load player details
- ✅ Save player details
- ✅ Field validation (GPA, SAT, ACT)
- ✅ Photo upload
- ✅ Photo compression
- ✅ Role-based access (parent read-only)
- ✅ Auto-save debouncing
- ✅ Error handling

#### Mock Implementations
**File:** `MockPreferenceManager.swift`
- ✅ Mock for all ViewModels
- ✅ Success/failure scenarios
- ✅ Configurable delays

---

## Coverage Analysis Tasks

### 1. Run Coverage Report

**Command:**
```bash
cd TheRecruitingCompass
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES \
  -resultBundlePath ./TestResults.xcresult
```

**Extract Coverage:**
```bash
xcrun xccov view --report ./TestResults.xcresult
```

### 2. Analyze Coverage by File

**Priority Files (Must be >80%):**

#### Services
- ✅ `PreferenceServiceImpl.swift` - Core JSONB service
  - **Focus:** Error paths, edge cases, JSONB parsing failures

#### ViewModels
- ✅ `NotificationPreferencesViewModel.swift`
  - **Focus:** All toggle paths, debouncing, reset
- ✅ `HomeLocationViewModel.swift`
  - **Focus:** Geocoding success/failure, coordinate validation
- ✅ `DashboardCustomizationViewModel.swift`
  - **Focus:** Bulk select/deselect, individual toggles
- ✅ `SchoolPreferencesViewModel.swift`
  - **Focus:** Template application, reorder logic, validation
- ✅ `PlayerDetailsViewModel.swift`
  - **Focus:** Photo upload/compression, validation, role checks

#### Models
- ✅ All Codable models have encode/decode tests

---

## Gap Analysis Checklist

### PreferenceService
- [ ] JSONB parsing error (malformed data)
- [ ] Network timeout scenarios
- [ ] 401 unauthorized (expired session)
- [ ] 403 forbidden (parent trying to edit player details)
- [ ] 500 server error retry logic
- [ ] Concurrent save operations (race conditions)
- [ ] Very large data (>1MB JSONB)

### Notification Preferences
- [ ] Rapid toggle changes (debounce validation)
- [ ] Stepper boundary values (0, 90)
- [ ] Disabled nested toggle when parent off
- [ ] Reset while save in progress
- [ ] Load failure fallback to defaults

### Home Location
- [ ] Geocoding API timeout
- [ ] Geocoding API returns no results
- [ ] Invalid coordinates (out of range)
- [ ] Partial address (missing city/state)
- [ ] ZIP code validation (5 or 9 digits)
- [ ] State code validation (uppercase, 2 chars)

### Dashboard Customization
- [ ] Select all with partial selection
- [ ] Deselect all with partial selection
- [ ] Toggle during save
- [ ] Reset during save
- [ ] All disabled scenario (empty dashboard)

### School Preferences
- [ ] Reorder with single item
- [ ] Remove last preference
- [ ] Apply template over existing prefs
- [ ] Duplicate preference validation
- [ ] Invalid preference value types
- [ ] Priority recalculation after delete

### Player Details
- [ ] Photo >5MB (should compress)
- [ ] Photo compression failure
- [ ] Invalid GPA (negative, >5.0)
- [ ] Invalid SAT (< 400, > 1600)
- [ ] Invalid ACT (< 1, > 36)
- [ ] Parent role trying to save (should reject)
- [ ] Auto-save cancel on navigation
- [ ] Fit score recalculation trigger

---

## Additional Tests to Write (if gaps found)

### Edge Case Tests

#### PreferenceServiceImpl
```swift
func testFetchPreferences_WithMalformedJSONB_ThrowsError() async throws
func testSavePreferences_WithVeryLargeData_Succeeds() async throws
func testConcurrentSaves_LastWriteWins() async throws
```

#### NotificationPreferencesViewModel
```swift
func testRapidToggles_Debounces() async throws
func testStepperBoundaries_ClipsToRange() async throws
```

#### HomeLocationViewModel
```swift
func testGeocodingTimeout_ShowsError() async throws
func testInvalidCoordinates_Validated() async throws
```

#### DashboardCustomizationViewModel
```swift
func testSelectAll_WithPartialSelection_EnablesAll() async throws
func testDeselectAll_DisablesAll() async throws
```

#### SchoolPreferencesViewModel
```swift
func testRemoveLastPreference_EmptyState() async throws
func testApplyTemplate_ReplacesExisting() async throws
```

#### PlayerDetailsViewModel
```swift
func testPhotoUpload_Compresses5MBImage() async throws
func testParentRole_CannotSave_ShowsError() async throws
func testInvalidGPA_ShowsValidationError() async throws
```

---

## Test Execution Checklist

### Pre-Test
- [ ] Build succeeds (0 errors)
- [ ] No compiler warnings
- [ ] Mock implementations ready

### During Test
- [ ] All tests pass
- [ ] No flaky tests (run 3x to verify)
- [ ] No timing issues (async tests stable)

### Post-Test
- [ ] Coverage report generated
- [ ] Coverage >80% on all files
- [ ] Gaps documented
- [ ] Additional tests written (if needed)

---

## Success Criteria

**Passing Criteria:**
- ✅ All 125+ existing tests pass
- ✅ PreferenceServiceImpl >85% coverage
- ✅ All ViewModels >80% coverage
- ✅ All Models >90% coverage (simple encode/decode)
- ✅ Critical paths 100% covered:
  - Save success/failure
  - Load success/failure
  - Validation (GPA/SAT/ACT/coordinates)
  - Role-based access (parent read-only)
  - Photo upload/compression

**Acceptance:**
- ✅ No critical gaps in error handling
- ✅ All edge cases tested
- ✅ Debouncing logic validated
- ✅ Concurrent operation safety verified

---

## Known Areas of High Coverage

Based on test file review:
- ✅ **PreferenceService** - Comprehensive mocking, all CRUD operations
- ✅ **ViewModels** - Load/save/error paths well covered
- ✅ **Player Details** - Extensive validation and role tests
- ✅ **School Preferences** - Template and reorder logic tested

**Expected Result:** 85-90% coverage overall, with strong coverage on critical business logic.

---

## Next Steps (After Build Fix)

1. **Run full test suite** - Verify all 125+ tests pass
2. **Generate coverage report** - Analyze file-by-file coverage
3. **Identify gaps** - Document any <80% files
4. **Write additional tests** - Fill gaps if needed
5. **Re-run coverage** - Confirm >80% achieved
6. **Document results** - Update MEMORY.md with final metrics

---

## Team Coordination

**Unit-Test-Engineer:**
- Execute test run
- Generate coverage report
- Identify gaps

**Feature-Developer (Me):**
- Review gap analysis
- Write additional tests if needed
- Validate edge cases

**Team-Lead:**
- Approve coverage threshold
- Sign off on test completeness
- Authorize merge to main

---

**Status:** Ready to execute once build environment is clean.
