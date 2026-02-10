# School Detail Refactoring Plan

**Date:** February 10, 2026
**Goal:** Reduce complexity, improve maintainability, enhance testability

---

## Current Metrics
- **SchoolDetailView:** 404 lines
- **SchoolDetailViewModel:** 511 lines
- **Components:** 24 files
- **@Published properties:** 20+

## Target Metrics
- **SchoolDetailView:** ~200 lines (50% reduction)
- **SchoolDetailViewModel:** ~400 lines (20% reduction)
- **Components:** +3 new components
- **State groups:** 4 structured groups

---

## Phase 1: Component Extraction

### Files to Create
1. `SchoolStatusPickerSection.swift` - Extract lines 328-377 from view
2. `SchoolBasicInfoSection.swift` - Extract lines 273-326 from view (display part)
3. `InfoRow.swift` - Move to Shared/Components (lines 380-397)

### Expected Outcome
- SchoolDetailView: 404 → ~250 lines
- 3 new reusable components
- Better separation of concerns

---

## Phase 2: ViewModel State Grouping

### New State Structures
```swift
struct EditingState {
  var notes: NotesEditState
  var privateNotes: NotesEditState
  var basicInfo: BasicInfoEditState
  var coachingPhilosophy: PhilosophyEditState
}

struct NotesEditState {
  var isEditing: Bool
  var content: String
  var isSaving: Bool
}
```

### Helpers to Add
1. `handleError()` - Consolidate error handling
2. `withLoading()` - Async operation wrapper
3. Computed properties for derived state

### Expected Outcome
- Clearer state organization
- Less boilerplate in async methods
- Consistent error handling

---

## Phase 3: View Alert Consolidation

### Alert System
```swift
enum AlertType: Identifiable {
  case error(String)
  case deleteError(String)
  case deleteConfirmation
}
```

### Expected Outcome
- 3 alert modifiers → 1
- Cleaner view code
- Easier alert management

---

## Phase 4: Testing & Verification

### Test Updates Needed
1. Update ViewModel tests for new state structure
2. Add component tests for extracted views
3. Verify all existing tests pass
4. Run build verification

### Success Criteria
- ✅ All tests passing
- ✅ Build succeeds (0 errors)
- ✅ No functionality regressions
- ✅ Code coverage maintained

---

## Rollout Order

1. **Phase 1A:** Create InfoRow shared component (5 min)
2. **Phase 1B:** Create SchoolStatusPickerSection (15 min)
3. **Phase 1C:** Create SchoolBasicInfoSection (15 min)
4. **Phase 2A:** Add state structures (20 min)
5. **Phase 2B:** Add helper methods (15 min)
6. **Phase 2C:** Migrate ViewModel to use new patterns (30 min)
7. **Phase 3A:** Update View to use new components (20 min)
8. **Phase 3B:** Consolidate alerts (15 min)
9. **Phase 4:** Update tests and verify (30 min)

**Total Estimated Time:** ~2.5 hours

---

## Risk Mitigation

- Incremental commits after each phase
- Verify build after each major change
- Keep old code commented during transition
- Run tests frequently

---

## Next Steps

Execute phases in order, commit after each successful phase.
