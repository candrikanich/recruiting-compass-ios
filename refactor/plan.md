# SwiftUI Modernization Refactor Plan
**Created:** 2026-02-15
**Scope:** NotificationsListViewModel & NotificationsListView
**Goal:** Migrate from legacy ObservableObject to modern @Observable (iOS 17+)

---

## Initial State Analysis

**Current Architecture:**
- ViewModel: Uses ObservableObject protocol with @Published properties
- View: Uses @ObservedObject property wrapper
- Dependencies: Combine framework for @Published
- Thread Safety: @MainActor annotation (✅ correct)

**Problem Areas:**
1. Legacy observable pattern (iOS 16 and earlier)
2. Duplicate methods causing confusion
3. Unused computed property aliases
4. Redundant compatibility properties

**Test Coverage:** 126+ tests passing (all must remain green)

---

## Refactoring Tasks

### HIGH PRIORITY (Breaking Changes)

#### Task 1: Migrate ViewModel to @Observable ⚠️
**Risk:** HIGH (breaking change, affects View)
**Files:** `NotificationsListViewModel.swift`
**Changes:**
- [ ] Remove `Combine` import (line 1)
- [ ] Add `Observation` import
- [ ] Change `ObservableObject` to `@Observable` (line 11)
- [ ] Remove all `@Published` property wrappers (lines 14-25)
- [ ] Keep `private(set)` for read-only properties

**Dependencies:** Must update View simultaneously

---

#### Task 2: Update View to use @State ⚠️
**Risk:** HIGH (breaking change, depends on Task 1)
**Files:** `NotificationsListView.swift`
**Changes:**
- [ ] Change `@ObservedObject var viewModel` to `@State private var viewModel` (line 4)
- [ ] Verify all bindings still work with new pattern

**Dependencies:** Requires Task 1 completion

---

### MEDIUM PRIORITY (Safe Removals)

#### Task 3: Remove Duplicate Method
**Risk:** LOW (unused code)
**Files:** `NotificationsListViewModel.swift`
**Changes:**
- [ ] Delete `markAsRead(_ id: String)` wrapper method (lines 139-141)

**Validation:** Tests call `markAsRead(id:)` directly, wrapper is unused

---

#### Task 4: Remove Redundant Computed Properties
**Risk:** LOW (unused code)
**Files:** `NotificationsListViewModel.swift`
**Changes:**
- [ ] Delete `hasUnreadNotifications` (line 55)
- [ ] Delete `hasReadNotifications` (line 61)

**Validation:** Tests only use `hasUnread` and `hasRead`, not the aliases

---

#### Task 5: Clean Up Compatibility Aliases
**Risk:** LOW-MEDIUM (need verification)
**Files:** `NotificationsListViewModel.swift`
**Changes:**
- [ ] Keep `activeFilterCount` (line 89-94) - USED in tests
- [ ] Evaluate and remove unused aliases:
  - [ ] `activeFilter` (lines 69-72) - if unused
  - [ ] `searchQuery` (lines 74-77) - if unused
  - [ ] `navigationPath` (lines 79-87) - if unused

**Validation:** Run grep to confirm usage before deletion

---

## Validation Checklist

After each task:
- [ ] All tests passing (126+ tests)
- [ ] No build errors
- [ ] No SwiftUI preview errors
- [ ] No broken imports
- [ ] View updates correctly on state changes
- [ ] Navigation still works

---

## De-Para Mapping

| Before | After | Status |
|--------|-------|--------|
| `import Combine` | `import Observation` | Pending |
| `ObservableObject` | `@Observable` | Pending |
| `@Published var prop` | `var prop` | Pending |
| `@ObservedObject var vm` | `@State private var vm` | Pending |
| `markAsRead(_ id:)` | (deleted - use `markAsRead(id:)`) | Pending |
| `hasUnreadNotifications` | (deleted - use `hasUnread`) | Pending |
| `hasReadNotifications` | (deleted - use `hasRead`) | Pending |
| `activeFilter?` | (evaluate for deletion) | Pending |
| `searchQuery?` | (evaluate for deletion) | Pending |
| `navigationPath?` | (evaluate for deletion) | Pending |

---

## Execution Order

**Phase 1: Analysis**
1. ✅ Verify alias property usage
2. ✅ Confirm test coverage

**Phase 2: Safe Removals (Tasks 3-5)**
3. Remove duplicate method
4. Remove redundant properties
5. Remove unused aliases

**Phase 3: Breaking Changes (Tasks 1-2)**
6. Migrate ViewModel to @Observable
7. Update View to @State
8. Run full test suite

**Phase 4: Validation**
9. Run all tests
10. Build app
11. Test UI manually
12. Commit changes

---

## Rollback Strategy

**If tests fail:**
1. Git reset to checkpoint before breaking changes
2. Re-apply safe removals only
3. Investigate test failures
4. Fix and retry

**Checkpoints:**
- Before Task 3: Initial state
- After Task 5: Safe removals complete
- After Task 7: Full migration complete
