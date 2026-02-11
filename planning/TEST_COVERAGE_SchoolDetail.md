# School Detail Test Coverage Report

**Generated:** February 10, 2026
**Reviewer:** Claude Code
**Implementation:** SchoolDetailViewModel + SchoolDetailView

---

## Executive Summary

**Overall Test Coverage: ~45%**

- ✅ **Well-tested:** Phase 3 (Fit Score, College Data), Phase 4 (Coaches, Delete, Philosophy), Priority Tier
- ❌ **Missing tests:** Phase 1 (Core loading, status, favorite), Phase 2 (Notes, Pros/Cons, Basic Info)
- ❌ **Missing tests:** View layer (SchoolDetailView accessibility, UI components)
- ❌ **Missing tests:** Integration tests across phases

---

## Test Files Found

### ViewModel Tests (3 files)
1. **SchoolDetailViewModelPhase3Tests.swift** (10 tests)
   - Path: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/`
   - Tests: Fit Score calculation, College Scorecard lookup, Division recommendations

2. **SchoolDetailViewModelPhase4Tests.swift** (9 tests)
   - Path: `TheRecruitingCompassTests/Features/Schools/ViewModels/`
   - Tests: Coaches loading, Coaching philosophy editing, School deletion

3. **SchoolDetailViewModelPriorityTierTests.swift** (5 tests)
   - Path: `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/`
   - Tests: Priority tier updates (A/B/C/D/nil)

### Component Tests (2 files)
4. **PriorityTierSelectorSimpleTests.swift**
   - Path: `TheRecruitingCompassTests/Features/Schools/Components/`
   - Tests: Priority tier selector UI component

5. **SchoolCardViewTests.swift**
   - Path: `TheRecruitingCompassTests/Features/Schools/Components/`
   - Tests: School list card view

### View Tests
- ❌ **None found** for `SchoolDetailView`

---

## Feature Coverage Breakdown

### ✅ Phase 3: Fit Score & College Data (100% tested)

**Tested:**
- `loadFitScore()` - Success, loading state, error handling
- `lookupCollegeData()` - Success, not found, API errors, network errors
- Division recommendations based on fit score
- Integration: Fit score loads automatically with school

**Test Files:**
- `SchoolDetailViewModelPhase3Tests.swift` (10 tests)

**Test Quality:** Excellent - covers happy path, error cases, edge cases

---

### ✅ Phase 4: Coaches, Philosophy, Delete (85% tested)

**Tested:**
- `loadCoaches()` - Success, empty list, failure
- `startEditingCoachingPhilosophy()` - Populates form correctly
- `cancelEditingCoachingPhilosophy()` - Clears form
- `saveCoachingPhilosophy()` - Success, empty fields, failure
- `confirmDelete()` - Shows confirmation dialog
- `deleteSchool()` - Simple delete, cascade fallback, failure

**Not Tested:**
- Computed property: `hasCoaches`
- Edge case: Delete while editing (should cancel edits?)
- Navigation to coaches list

**Test Files:**
- `SchoolDetailViewModelPhase4Tests.swift` (9 tests)

**Test Quality:** Very Good - covers most scenarios

---

### ✅ Priority Tier (100% tested)

**Tested:**
- `updatePriorityTier()` - Set to A/B/C/D, clear to nil
- Loading state management
- Error handling and error messages

**Test Files:**
- `SchoolDetailViewModelPriorityTierTests.swift` (5 tests)

**Test Quality:** Excellent - comprehensive coverage

---

### ❌ Phase 1: Core Loading, Status, Favorite (0% tested)

**NOT Tested:**
- `loadSchool()` - Core school loading
- `updateStatus()` - Status picker changes
- `toggleFavorite()` - Star button toggle
- Loading state management for initial load
- Error handling for failed school fetch
- Status history loading
- Parallel loading (school + fit score + coaches)

**Impact:** **HIGH** - These are critical user-facing features
**Test File Needed:** `SchoolDetailViewModelPhase1Tests.swift`

**Recommended Tests (12 tests):**
1. `testLoadSchool_Success()` - Loads school data
2. `testLoadSchool_SetsLoadingState()` - Shows/hides loading spinner
3. `testLoadSchool_NoFamily()` - Handles missing family gracefully
4. `testLoadSchool_Failure()` - Shows error message
5. `testLoadSchool_LoadsStatusHistory()` - Fetches status changes
6. `testLoadSchool_LoadsFitScoreInParallel()` - Non-blocking fit score
7. `testLoadSchool_LoadsCoachesInParallel()` - Non-blocking coaches
8. `testUpdateStatus_Success()` - Updates status and history
9. `testUpdateStatus_SameStatus()` - No-op for unchanged status
10. `testUpdateStatus_Failure()` - Handles API error
11. `testToggleFavorite_OptimisticUpdate()` - Immediate UI update
12. `testToggleFavorite_RevertOnError()` - Rollback on failure

---

### ❌ Phase 2: Notes, Pros/Cons, Basic Info (0% tested)

**NOT Tested:**
- `startEditingNotes()` / `saveNotes()` / `cancelEditingNotes()`
- `startEditingPrivateNotes()` / `savePrivateNotes()` / `cancelEditingPrivateNotes()`
- `addPro()` / `removePro()`
- `addCon()` / `removeCon()`
- `startEditingBasicInfo()` / `saveBasicInfo()` / `cancelEditingBasicInfo()`
- Computed property: `privateNoteForCurrentUser`
- Computed property: `currentUserId`
- Computed property: `isEditingAnything`

**Impact:** **HIGH** - These are core editing features used frequently
**Test File Needed:** `SchoolDetailViewModelPhase2Tests.swift`

**Recommended Tests (20 tests):**

**Notes Tests (6 tests):**
1. `testStartEditingNotes_PopulatesField()`
2. `testSaveNotes_Success()`
3. `testSaveNotes_EmptyString_NoOp()`
4. `testCancelEditingNotes_ClearsState()`
5. `testSaveNotes_Failure_ShowsError()`
6. `testSaveNotes_LoadingState()`

**Private Notes Tests (6 tests):**
7. `testPrivateNoteForCurrentUser_ReturnsCorrectNote()`
8. `testStartEditingPrivateNotes_PopulatesField()`
9. `testSavePrivateNotes_Success()`
10. `testSavePrivateNotes_ClearsNote_WhenEmpty()`
11. `testSavePrivateNotes_NoFamily_ShowsError()`
12. `testCancelEditingPrivateNotes_ClearsState()`

**Pros & Cons Tests (6 tests):**
13. `testAddPro_Success_ClearsInput()`
14. `testAddPro_EmptyString_NoOp()`
15. `testRemovePro_Success()`
16. `testAddCon_Success_ClearsInput()`
17. `testAddCon_NoFamily_ShowsError()`
18. `testRemoveCon_Success()`

**Basic Info Tests (2 tests):**
19. `testStartEditingBasicInfo_PopulatesForm()`
20. `testSaveBasicInfo_Success()`

---

### ❌ View Layer Tests (0% tested)

**Missing Tests:**
- `SchoolDetailView` accessibility labels
- Component rendering based on state
- Alert presentation (error, delete confirmation)
- Navigation (coaches, add interaction)
- Sheet presentation (basic info, coaching philosophy)
- Pull-to-refresh functionality
- Task initialization on view appear

**Impact:** **MEDIUM** - View testing is important but less critical than ViewModel
**Test File Needed:** `SchoolDetailViewAccessibilityTests.swift`

**Recommended Tests (15+ tests):**
1. VoiceOver labels for all interactive elements
2. Delete button accessibility
3. Error state accessibility
4. Loading state accessibility
5. Alert accessibility
6. Navigation button hints
7. Pull-to-refresh accessibility
8. Sheet accessibility (basic info, philosophy)
9. Status picker accessibility
10. Favorite star button accessibility
11. Notes section accessibility
12. Pros/Cons list accessibility
13. Fit score section accessibility
14. Map accessibility
15. Quick actions accessibility

---

### ❌ Component Tests (Partial)

**Components with Tests:**
- ✅ `PriorityTierSelector`
- ✅ `SchoolCardView`

**Components WITHOUT Tests (Phase 2-4):**
- ❌ `SchoolNotesSection`
- ❌ `SchoolProsConsSection`
- ❌ `SchoolBasicInfoDisplaySection`
- ❌ `SchoolBasicInfoSheet`
- ❌ `FitScoreSection`
- ❌ `DivisionRecommendationBanner`
- ❌ `SchoolMapView`
- ❌ `CollegeDataSection`
- ❌ `SchoolCoachesPanel`
- ❌ `SchoolQuickActions`
- ❌ `SchoolCoachingPhilosophySection`
- ❌ `SchoolCoachingPhilosophySheet`
- ❌ `SchoolDocumentsSection`
- ❌ `SchoolAttributionSection`
- ❌ `SchoolDetailHeader`
- ❌ `SchoolStatusPickerSection`
- ❌ `SchoolStatusHistorySection`

**Impact:** **LOW-MEDIUM** - Component tests are nice-to-have, not critical

---

### ❌ Integration Tests (0% tested)

**Missing Scenarios:**
- Full user flow: Load → Edit Notes → Save → Refresh
- Full user flow: Load → Update Status → View History
- Full user flow: Load → Lookup College Data → Save
- Full user flow: Load → Delete → Navigate back
- Concurrent operations: Editing while loading coaches
- Error recovery: Network error → Retry → Success
- State transitions: Loading → Loaded → Editing → Saving → Loaded

**Impact:** **MEDIUM** - Integration tests catch real-world issues
**Test File Needed:** `SchoolDetailIntegrationTests.swift`

---

## Helper Methods & Computed Properties

### Tested:
- ❌ None

### Not Tested:
- `handleError()` - Centralized error handling
- `withLoading()` - Generic loading state wrapper
- `currentUserId` - User ID from AuthManager
- `privateNoteForCurrentUser` - Filters private notes
- `hasCoaches` - Boolean check
- `canLookupCollegeData` - Guard for lookup button
- `isEditingAnything` - Multi-edit guard

**Impact:** **LOW** - These are indirectly tested through feature tests, but direct tests would improve confidence

---

## Test Quality Assessment

### Strengths:
1. ✅ Phase 3 & 4 tests are comprehensive and well-structured
2. ✅ Good use of mocks (`MockSchoolsService`, `MockFitScoreService`, etc.)
3. ✅ Tests cover both happy path and error cases
4. ✅ Async/await patterns properly tested with `@MainActor`
5. ✅ Loading state management tested where applicable

### Weaknesses:
1. ❌ **Critical gap:** Phase 1 core features (loading, status, favorite) have ZERO tests
2. ❌ **Critical gap:** Phase 2 editing features (notes, pros/cons, basic info) have ZERO tests
3. ❌ No accessibility tests for `SchoolDetailView`
4. ❌ No component-level tests for Phase 2-4 UI components
5. ❌ No integration tests for multi-step flows
6. ❌ Inconsistent test file locations (some in `TheRecruitingCompass/TheRecruitingCompassTests/`, others in `TheRecruitingCompassTests/`)

---

## Coverage Estimate by Feature Area

| Feature Area | Tested | Not Tested | Coverage |
|--------------|--------|------------|----------|
| **Phase 1: Core** | 0 | 12 | 0% |
| **Phase 2: Editing** | 0 | 20 | 0% |
| **Phase 3: Fit/Data** | 10 | 0 | 100% |
| **Phase 4: Coaches/Delete** | 9 | 2 | 82% |
| **Priority Tier** | 5 | 0 | 100% |
| **View Layer** | 0 | 15+ | 0% |
| **Components** | 2 | 17 | 11% |
| **Integration** | 0 | 7+ | 0% |
| **TOTAL** | **26** | **73+** | **~26%** |

**Overall ViewModel Coverage:** ~45% (26 ViewModel tests / ~57 ViewModel features)
**Overall Component Coverage:** ~11% (2 / 19)
**Overall View Coverage:** 0%

---

## Priority Recommendations

### 🔴 Critical Priority (Implement ASAP)

**1. Phase 1 ViewModel Tests (Estimated: 2-3 hours)**
- File: `SchoolDetailViewModelPhase1Tests.swift`
- Tests: 12 tests covering `loadSchool()`, `updateStatus()`, `toggleFavorite()`
- Impact: HIGH - These are the most-used features
- Justification: Zero coverage on core loading and status management is a critical risk

**2. Phase 2 ViewModel Tests (Estimated: 3-4 hours)**
- File: `SchoolDetailViewModelPhase2Tests.swift`
- Tests: 20 tests covering notes, pros/cons, basic info editing
- Impact: HIGH - These are frequently-used editing features
- Justification: Zero coverage on editing features increases bug risk

### 🟡 Medium Priority (Next Sprint)

**3. SchoolDetailView Accessibility Tests (Estimated: 2 hours)**
- File: `SchoolDetailViewAccessibilityTests.swift`
- Tests: 15+ tests for VoiceOver, accessibility labels, hints
- Impact: MEDIUM - Important for WCAG AA compliance
- Justification: Consistent with existing accessibility standards in project

**4. Integration Tests (Estimated: 2-3 hours)**
- File: `SchoolDetailIntegrationTests.swift`
- Tests: 7+ tests for multi-step user flows
- Impact: MEDIUM - Catches real-world interaction bugs
- Justification: Verifies features work together correctly

### 🟢 Low Priority (Future)

**5. Component Tests for Phase 2-4 UI (Estimated: 5-6 hours)**
- Files: Individual test files per component
- Tests: 50+ tests across 17 untested components
- Impact: LOW - Components are already tested indirectly via integration
- Justification: Nice-to-have, but not critical

---

## Estimated Effort to Reach 80% Coverage

**Current Coverage:** ~26%
**Target Coverage:** 80%
**Gap:** 54% (~100 additional tests)

**Breakdown:**
- Phase 1 ViewModel Tests: 12 tests (2-3 hours)
- Phase 2 ViewModel Tests: 20 tests (3-4 hours)
- View Accessibility Tests: 15 tests (2 hours)
- Integration Tests: 7 tests (2-3 hours)
- Component Tests (selective): 20 tests (3-4 hours)
- **Total Estimated Effort: 12-18 hours**

---

## Recommendations Summary

1. **Immediate Action (This Week):**
   - Write Phase 1 ViewModel tests (loading, status, favorite)
   - Write Phase 2 ViewModel tests (notes, pros/cons, basic info)
   - **Estimated:** 5-7 hours, +32 tests

2. **Next Sprint:**
   - Add SchoolDetailView accessibility tests
   - Add integration tests for critical flows
   - **Estimated:** 4-6 hours, +22 tests

3. **Future Iterations:**
   - Gradually add component tests as bugs are found
   - Consider snapshot testing for complex UI components
   - **Estimated:** 5-6 hours, +20+ tests

4. **Process Improvements:**
   - Standardize test file locations (all tests in `TheRecruitingCompassTests/`)
   - Add pre-commit hook to enforce 80% coverage on new code
   - Use TDD for new features going forward

---

## Test File Organization Issue

**Problem:** Tests are in inconsistent locations:
- Some in `TheRecruitingCompass/TheRecruitingCompassTests/Features/Schools/ViewModels/`
- Others in `TheRecruitingCompassTests/Features/Schools/ViewModels/`

**Recommendation:** Standardize to `TheRecruitingCompassTests/` as the root (no nested `TheRecruitingCompass/` prefix)

---

## Conclusion

The School Detail feature has **good test coverage for newer features (Phases 3-4, Priority Tier)** but **critical gaps in core functionality (Phases 1-2)**. This suggests that:

1. Testing discipline improved during later development phases ✅
2. Earlier phases (Phase 1-2) need retroactive test coverage ❌
3. View and component layers need accessibility testing ❌

**Risk Level:** **MEDIUM-HIGH**
- The lack of tests for core loading and editing features increases the risk of regressions.
- The well-tested Phase 3-4 features demonstrate good testing capability exists.

**Action Required:** Prioritize Phase 1 and Phase 2 ViewModel tests immediately to reduce risk before moving to new features.

---

**End of Report**
