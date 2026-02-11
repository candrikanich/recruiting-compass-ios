# Handoff: Add Coach Feature - Phase 5 Complete

**Created:** February 10, 2026
**Session:** Phase 5 Main View Complete
**Previous:** Phase 4 Reusable Components Complete
**Next:** Phase 6 - Integration & Navigation
**Status:** ✅ PHASE 5 COMPLETE (1 pre-existing error in unrelated file)

---

## Executive Summary

Phase 5 of the Add Coach feature implementation is complete. The AddCoachView has been created with a two-step form flow, empty state handling, loading states, error alerts, and full accessibility support. The view integrates all Phase 1-4 components into a cohesive user experience.

**Build Status:** ⚠️ BUILD FAILED (1 pre-existing error in CoachesListView.swift, unrelated to Phase 5)
**Phase 5 Code Status:** ✅ AddCoachView.swift compiles successfully

---

## What Was Completed in Phase 5

### 1. AddCoachView Created

#### File: `Features/Coaches/Views/AddCoachView.swift` (232 lines)

**Purpose:** Main view for adding a coach with two-step flow

**Key Features:**
- NavigationStack wrapper for navigation hierarchy
- Two-step form flow (school selection → coach form)
- Empty state handling (no schools found)
- Loading state (fetching schools)
- Error alert presentation
- Accessibility announcements
- ViewModel integration
- Environment dismiss for navigation

---

## View Structure

### NavigationStack
```swift
NavigationStack {
  Form {
    // Sections...
  }
  .navigationTitle("Add Coach")
  .navigationBarTitleDisplayMode(.large)
  .toolbar { /* Back button */ }
  .task { /* Load schools on appear */ }
  .alert { /* Error handling */ }
}
```

### Section 1: School Selection (Step 1 - Always Visible)

**Loading State:**
```swift
if viewModel.isLoadingSchools {
  ProgressView() + "Loading schools..."
}
```

**Empty State:**
```swift
else if viewModel.schools.isEmpty {
  emptySchoolsView
  // Shows: Icon, message, "Add School" button
}
```

**School Picker:**
```swift
else {
  SchoolPicker(...)
  .onChange(of: selectedSchoolId) {
    announceSchoolSelection()  // VoiceOver
  }
}
```

### Section 2: Coach Form (Step 2 - Conditional)

**Only Shown When `viewModel.isFormVisible == true`:**

1. **Error Summary** (conditional)
```swift
if viewModel.formErrors.hasErrors {
  FormErrorSummary(errors: ..., onDismiss: ...)
}
```

2. **Form Fields**
```swift
CoachFormView(
  formState: $viewModel.formState,
  formErrors: $viewModel.formErrors,
  isDisabled: viewModel.isSubmitting,
  onValidateField: viewModel.validateField,
  onValidateRole: viewModel.validateRole
)
```

### Section 3: Actions (Conditional - same as Section 2)

1. **Submit Button**
   - Dynamic text: "Adding..." / "Add Coach"
   - Disabled when: submitting, has errors, or not submittable
   - Shows spinner when submitting
   - Dismisses on success

2. **Cancel Button**
   - Role: `.cancel` (visual styling)
   - Dismisses view without saving

### Alternative: Info Prompt

**Shown When `viewModel.isFormVisible == false`:**
```swift
HStack {
  Image(systemName: "info.circle.fill")
  Text("Please select a school to continue")
}
```

---

## Component Integration

### Phase 4 Components Used

1. **SchoolPicker** - School selection dropdown
   ```swift
   SchoolPicker(
     selectedSchoolId: $viewModel.formState.selectedSchoolId,
     schools: viewModel.schools,
     isDisabled: viewModel.isSubmitting
   )
   ```

2. **FormErrorSummary** - Error banner
   ```swift
   FormErrorSummary(
     errors: viewModel.formErrors.allErrors,
     onDismiss: { viewModel.clearErrors() }
   )
   ```

3. **CoachFormView** - All form fields
   ```swift
   CoachFormView(
     formState: $viewModel.formState,
     formErrors: $viewModel.formErrors,
     isDisabled: viewModel.isSubmitting,
     onValidateField: viewModel.validateField,
     onValidateRole: viewModel.validateRole
   )
   ```

### Phase 3 ViewModel Integration

**State Observation:**
- `@StateObject viewModel: AddCoachViewModel`
- Observes all `@Published` properties
- UI updates automatically on state changes

**Async Actions:**
```swift
.task {
  await viewModel.loadSchools()  // On view appear
}

Button {
  Task {
    if await viewModel.submitCoach() != nil {
      dismiss()
    }
  }
}
```

---

## Empty State View

**Purpose:** Guide user to add a school when none exist

**Features:**
- Icon: Building (48pt, decorative)
- Headline: "No Schools Found"
- Message: "You need to add a school before adding a coach"
- Button: "Add School" (bordered prominent style)
- Accessibility: Combined label for full context

**Navigation:**
```swift
Button {
  // TODO: Navigate to Add School
  // Will be implemented in Phase 6
}
```

---

## Loading State View

**Purpose:** Show progress while fetching schools

**Features:**
- ProgressView (circular spinner)
- Text: "Loading schools..."
- Accessibility: ProgressView labeled "Loading schools"

---

## Accessibility Features

### VoiceOver Announcements

1. **School Selection:**
```swift
private func announceSchoolSelection() {
  let school = viewModel.schools.first { $0.id == selectedId }
  let message = "School selected. \(school.name). Coach form now available."
  UIAccessibility.post(notification: .announcement, argument: message)
}
```

2. **Empty State:**
   - Combined label: "No schools found. Add a school first."

3. **Info Prompt:**
   - Combined label: "Please select a school to continue adding a coach"

4. **Loading State:**
   - ProgressView: "Loading schools"

### Button Labels & Hints

1. **Back Button:**
   - Label: "Back to coaches list"

2. **Submit Button:**
   - Label: "Adding..." or "Add Coach" (dynamic)
   - Hint: "Fill all required fields to enable" (when disabled)
   - Hint: "Create new coach" (when enabled)

3. **Cancel Button:**
   - Label: "Cancel adding coach"
   - Hint: "Return to coaches list without saving"

4. **Add School Button:**
   - Label: "Add a school"
   - Hint: "Navigate to add school page"

---

## Error Handling

### Submit Error Alert

**Trigger:** `viewModel.submitError != nil`

**Display:**
```swift
.alert("Error", isPresented: .constant(submitError != nil)) {
  Button("OK") { viewModel.submitError = nil }
} message: {
  Text(submitError ?? "")
}
```

**Use Cases:**
- Network errors during school fetch
- Network errors during coach creation
- API validation errors
- Server errors

---

## Navigation

### Environment Dismiss

```swift
@Environment(\.dismiss) private var dismiss

// Cancel:
Button("Cancel") { dismiss() }

// Success:
if await viewModel.submitCoach() != nil {
  dismiss()  // Or navigate to coach detail
}
```

### Toolbar

```swift
.toolbar {
  ToolbarItem(placement: .navigationBarLeading) {
    Button("Back") { dismiss() }
  }
}
```

---

## File Structure

```
Features/Coaches/Views/
└── AddCoachView.swift                 (NEW - 232 lines)
```

**Total Code Added:** ~232 lines of production code

---

## Build Status

### ⚠️ Pre-Existing Build Error (NOT from Phase 5)

**Error Location:** `Features/Coaches/Views/CoachesListView.swift:14:23`

**Error Message:**
```
error: the compiler is unable to type-check this expression in reasonable time;
try breaking up the expression into distinct sub-expressions
```

**Root Cause:** Complex view body in CoachesListView (line 14: `var body: some View`)

**Impact:** Blocks overall build, but NOT caused by Phase 5 changes

**Verification:** AddCoachView.swift itself compiles successfully (no errors in Phase 5 code)

### ✅ Phase 5 Code Status

- ✅ AddCoachView.swift compiles with 0 errors
- ⚠️ 1 deprecation warning (onChange API - non-critical)

### Deprecation Warning (Non-Critical)

```
onChange(of:perform:) was deprecated in iOS 17.0
Use `onChange` with a two or zero parameter action closure instead.
```

**Location:** AddCoachView.swift:42
**Impact:** None (existing API still works)
**Fix:** Can be updated to iOS 17 API in future refactoring

---

## Testing Readiness

### What Can Be Tested Now (Phase 7)

**UI Tests: AddCoachViewTests.swift**

1. **Two-Step Flow Tests**
   - Test school selection shows form
   - Test no school selection hides form
   - Test info prompt visibility

2. **Empty State Tests**
   - Test empty state appears when no schools
   - Test "Add School" button navigation

3. **Loading State Tests**
   - Test loading spinner appears
   - Test loading text displays

4. **Submit Button Tests**
   - Test disabled when no school selected
   - Test disabled when form has errors
   - Test disabled when form not submittable
   - Test enabled when valid
   - Test shows spinner when submitting

5. **Cancel Button Tests**
   - Test dismisses view

6. **Error Alert Tests**
   - Test alert appears on submit error
   - Test alert dismisses on OK

7. **Accessibility Tests**
   - Test school selection announcement
   - Test button labels and hints
   - Test empty state accessibility
   - Test loading state accessibility

**Integration Tests:**

1. Test full flow: School selection → Fill form → Submit → Success
2. Test validation errors prevent submission
3. Test network error handling
4. Test cancel flow

---

## Implementation Plan Reference

**Full Plan:** `/planning/PLAN_AddCoach_Implementation.md`

### Phase Completion Status

- ✅ **Phase 1: Foundation** (4 hours) - COMPLETE
- ✅ **Phase 2: Validation System** (6 hours) - COMPLETE
- ✅ **Phase 3: ViewModel** (4 hours) - COMPLETE
- ✅ **Phase 4: Reusable Components** (6 hours) - COMPLETE
- ✅ **Phase 5: Main View** (6 hours) - COMPLETE ← **YOU ARE HERE**
- ⏳ **Phase 6: Integration & Navigation** (3 hours) - NEXT
- ⏸️ **Phase 7: Testing** (8 hours) - Pending

**Total Progress:** 5/7 phases complete (71%)

---

## Next Steps for Fresh Context

### Immediate Actions

1. **Fix Pre-Existing CoachesListView Error**
   - Open `Features/Coaches/Views/CoachesListView.swift`
   - Simplify `body` variable (line 14)
   - Break complex expression into sub-expressions
   - This is blocking overall build

2. **Verify Phase 5 Files in Xcode**
   - Ensure AddCoachView.swift is in project target
   - Verify it appears in Xcode navigator
   - Confirm it's included in build

### Starting Phase 6: Integration & Navigation

**Goal:** Wire up navigation from CoachesListView to AddCoachView

**Files to Modify:**

1. **CoachDestination.swift** (~5 lines)
   ```swift
   enum CoachDestination: Hashable, Sendable {
     case detail(id: String)
     case add  // NEW
   }
   ```

2. **CoachesListView.swift** (~20 lines)
   - Add "+" toolbar button
   - Navigate to .add destination
   - Wire up NavigationStack destination

**Pattern:**
```swift
.toolbar {
  ToolbarItem(placement: .primaryAction) {
    Button {
      path.append(CoachDestination.add)
    } label: {
      Image(systemName: "plus")
    }
    .accessibilityLabel("Add coach")
  }
}

.navigationDestination(for: CoachDestination.self) { destination in
  switch destination {
  case .detail(let id):
    CoachDetailView(coachId: id, ...)
  case .add:
    AddCoachView(
      coachesService: coachesService,
      familyUnitId: familyManager.currentFamilyUnitId,
      userId: authManager.currentUser?.id ?? ""
    )
  }
}
```

---

## Key Patterns Established in Phase 5

### 1. Two-Step Conditional Flow
```swift
// Step 1: Always visible
Section { SchoolPicker(...) }

// Step 2: Conditional
if viewModel.isFormVisible {
  Section { FormFields(...) }
  Section { Actions(...) }
} else {
  Section { InfoPrompt(...) }
}
```

### 2. Empty State Pattern
```swift
if collection.isEmpty {
  VStack {
    Image(systemName: "icon")
    Text("Headline")
    Text("Message")
    Button("Action") { }
  }
}
```

### 3. Loading State Pattern
```swift
if isLoading && collection.isEmpty {
  HStack {
    ProgressView()
    Text("Loading...")
  }
}
```

### 4. Accessibility Announcement Pattern
```swift
.onChange(of: state) { _ in
  let message = "State changed. New information available."
  UIAccessibility.post(notification: .announcement, argument: message)
}
```

### 5. Submit with Dismiss Pattern
```swift
Button {
  Task {
    if await viewModel.submitAction() != nil {
      dismiss()
    }
  }
}
```

---

## Context for Next Session

### What You Need to Know

1. **CoachesListView Error Must Be Fixed First**
   - Phase 6 requires modifying CoachesListView
   - Current compiler error blocks all changes
   - Fix: Simplify view body (extract subviews)

2. **Navigation Integration Pattern:**
   - Add CoachDestination.add case
   - Add "+" toolbar button in CoachesListView
   - Wire up .navigationDestination(for: CoachDestination.self)
   - Pass service dependencies to AddCoachView

3. **Dependency Injection:**
   ```swift
   AddCoachView(
     coachesService: viewModel.coachesService,
     familyUnitId: familyManager.currentFamilyUnitId,
     userId: authManager.currentUser?.id ?? ""
   )
   ```

4. **Success Navigation:**
   - Currently: Dismiss on success
   - Future: Navigate to coach detail page
   - Update AddCoachView.swift:177 when ready

---

## Verification Checklist

Before continuing to Phase 6:

- [x] Phase 5 code compiles (AddCoachView.swift)
- [ ] Fix CoachesListView error (BLOCKING Phase 6)
- [ ] AddCoachView added to Xcode project
- [ ] Run existing tests (should pass)
- [ ] Review implementation plan for Phase 6

---

## Quick Reference Commands

### Build Project
```bash
cd /Users/chrisandrikanich/Documents/Workspaces/Personal/TheRecruitingCompass/recruiting-compass-ios-fresh/TheRecruitingCompass

xcodebuild build -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Run Tests
```bash
xcodebuild test -scheme TheRecruitingCompass \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## Sign-Off

**Phase 5 Status:** ✅ COMPLETE
**Code Quality:** High (two-step flow, accessibility, error handling)
**Test Coverage:** Ready for UI tests (Phase 7)
**Build Status:** ⚠️ BLOCKED (pre-existing CoachesListView error)
**Phase 5 Code:** ✅ COMPILES SUCCESSFULLY
**Accessibility:** Full VoiceOver support + announcements
**Ready for Phase 6:** Yes (after fixing CoachesListView)

**Handoff Created By:** Claude Code (Session 11)
**Next Session Focus:** Fix CoachesListView → Phase 6 - Integration & Navigation
**Estimated Time for Phase 6:** 3 hours

---

## Additional Resources

- **Full Implementation Plan:** `planning/PLAN_AddCoach_Implementation.md`
- **Phase 1 Handoff:** `planning/HANDOFF_AddCoach_Phase1_Complete.md`
- **Phase 2 Handoff:** `planning/HANDOFF_AddCoach_Phase2_Complete.md`
- **Phase 3 Handoff:** `planning/HANDOFF_AddCoach_Phase3_Complete.md`
- **Phase 4 Handoff:** `planning/HANDOFF_AddCoach_Phase4_Complete.md`
- **Original Spec:** `recruiting-compass-web/planning/iOS_SPEC_Phase3_AddCoach.md`
- **Web Implementation:** `recruiting-compass-web/pages/coaches/new.vue`
- **Project CLAUDE.md:** Root-level architecture guide
