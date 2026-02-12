# Preferences Phase 4 - Refactoring Plan

**Date:** February 12, 2026
**Specialist:** refactor-specialist
**Task:** #9 - Refactor preferences code for maintainability

---

## 1. Diagnosis

### Code Smells Identified

#### A. **Duplicated UI Components** (Critical)
All 5 views duplicate the same UI patterns:

1. **Loading Overlay** (5 instances)
   - `ProgressView` with background opacity
   - Identical implementation in every view

2. **Error Alert** (5 instances)
   - `.alert("Error", isPresented:)` pattern
   - Manual error message clearing

3. **Success Toast** (5 instances)
   - Green banner with auto-dismiss after 3 seconds
   - Identical styling and animation

4. **Save Button Toolbar** (5 instances)
   - Confirmation action button
   - Disabled state logic for `hasUnsavedChanges`

5. **Preview Mock Services** (5 instances)
   - Identical `PreferenceManaging` mock in every preview
   - Duplicated 60+ lines across views

#### B. **Duplicated ViewModel Patterns** (High Priority)
Repeated logic across all 5 ViewModels:

1. **Success Message Auto-Clear** (5 instances)
   - Identical 11-line Task with 3-second delay
   - Same pattern in every save method
   - `NotificationPreferencesViewModel.swift:64-72`
   - `HomeLocationViewModel.swift:69-77`
   - `DashboardCustomizationViewModel.swift:57-65`
   - `SchoolPreferencesViewModel.swift:64-72`
   - `PlayerDetailsViewModel.swift:76-84`

2. **Load/Save Boilerplate** (5 instances)
   - Nearly identical error handling
   - Repetitive `isLoading` / `isSaving` state management
   - Common `errorMessage` clearing pattern

3. **`markAsChanged()` Methods** (5 instances)
   - Trivial 2-line methods repeated in every ViewModel
   - Could be consolidated into base functionality

#### C. **Inconsistent Naming Conventions**
Mixed naming patterns across ViewModels:

- `NotificationPreferencesViewModel`: `loadPreferences()` / `savePreferences()`
- `HomeLocationViewModel`: `loadLocation()` / `saveLocation()`
- `DashboardCustomizationViewModel`: `loadVisibility()` / `saveVisibility()`
- `SchoolPreferencesViewModel`: `loadPreferences()` / `savePreferences()`
- `PlayerDetailsViewModel`: `loadDetails()` / `saveDetails()`

**Issue:** Inconsistent naming reduces code scanability and increases cognitive load.

#### D. **Validation Logic Scattered**
Validation patterns mixed between ViewModels:

- `HomeLocationViewModel`: Input validation with auto-formatting (state uppercase, ZIP length)
- `PlayerDetailsViewModel`: Range validation (GPA 0.0-5.0, SAT 400-1600, ACT 1-36)
- No reusable validation utilities

#### E. **Auto-Save Complexity**
Two different auto-save implementations:

1. **HomeLocationViewModel** (lines 154-166)
   - Uses `$location` publisher + debounce
   - 500ms debounce on location changes

2. **PlayerDetailsViewModel** (lines 198-210)
   - Uses `$details` publisher + debounce
   - 500ms debounce on details changes

**Both could share common auto-save infrastructure.**

---

## 2. Refactoring Plan

### Phase 1: Extract Shared UI Components (High Impact)

#### Component 1: `PreferenceLoadingOverlay.swift`
**Purpose:** Reusable loading overlay
**Extraction:** All 5 views (lines 99-103 pattern)

**Before:**
```swift
.overlay {
  if viewModel.isLoading {
    ProgressView("Loading preferences...")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemBackground).opacity(0.8))
  }
}
```

**After:**
```swift
.overlay {
  PreferenceLoadingOverlay(
    isLoading: viewModel.isLoading,
    message: "Loading preferences..."
  )
}
```

**Benefits:**
- Single source of truth for loading UI
- Consistent styling across all views
- Easy to update globally (e.g., change opacity, add animation)

---

#### Component 2: `PreferenceErrorAlert.swift`
**Purpose:** Reusable error alert
**Extraction:** All 5 views (lines 105-113 pattern)

**Before:**
```swift
.alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
  Button("OK") {
    viewModel.errorMessage = nil
  }
} message: {
  if let errorMessage = viewModel.errorMessage {
    Text(errorMessage)
  }
}
```

**After:**
```swift
.preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
```

**Benefits:**
- Eliminates 9 lines of boilerplate per view
- Standardizes error handling UX
- Simplifies testing

---

#### Component 3: `PreferenceSuccessToast.swift`
**Purpose:** Reusable success toast
**Extraction:** All 5 views (lines 114-125 pattern)

**Before:**
```swift
.overlay(alignment: .top) {
  if let successMessage = viewModel.successMessage {
    Text(successMessage)
      .font(.callout)
      .foregroundColor(.white)
      .padding()
      .background(Color.green)
      .cornerRadius(8)
      .padding(.top, 8)
      .transition(.move(edge: .top).combined(with: .opacity))
  }
}
```

**After:**
```swift
.overlay(alignment: .top) {
  PreferenceSuccessToast(message: viewModel.successMessage)
}
```

**Benefits:**
- Consistent success feedback
- Easier to customize animation/styling
- Reduces view code by 12 lines each

---

#### Component 4: `PreferenceSaveButton.swift`
**Purpose:** Standardized toolbar save button
**Extraction:** All 5 views (toolbar sections)

**Before:**
```swift
.toolbar {
  ToolbarItem(placement: .confirmationAction) {
    Button("Save") {
      Task {
        await viewModel.savePreferences()
      }
    }
    .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
    .accessibilityLabel("Save notification preferences")
  }
}
```

**After:**
```swift
.preferenceSaveToolbar(
  hasUnsavedChanges: viewModel.hasUnsavedChanges,
  isSaving: viewModel.isSaving,
  action: { await viewModel.save() }
)
```

**Benefits:**
- Consistent save button behavior
- Centralized accessibility labels
- Simplified view code

---

#### Component 5: `PreferencePreviewMock.swift`
**Purpose:** Shared mock service for previews
**Extraction:** All 5 views (preview sections)

**Before:** (Duplicated 60+ lines in every view)
```swift
#Preview {
  final class PreviewMockService: PreferenceManaging {
    func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
      return NotificationSettings.default as? T
    }
    // ... more boilerplate
  }
  // ...
}
```

**After:**
```swift
#Preview {
  NavigationStack {
    NotificationPreferencesView(
      preferenceService: PreferencePreviewMock<NotificationSettings>()
    )
  }
}
```

**Benefits:**
- Eliminates 300+ lines of duplicated preview code
- Single source of truth for mock behavior
- Easier to update mock logic

---

### Phase 2: Consolidate ViewModel Patterns (Medium Impact)

#### Refactoring 1: Extract Success Message Logic
**Current:** 55 lines duplicated across 5 ViewModels

**Create:** `PreferenceViewModelHelpers.swift`

```swift
extension Task where Success == Void, Failure == Never {
  /// Clears a success message after 3 seconds
  static func clearSuccessMessage(
    _ message: String,
    binding: Binding<String?>
  ) -> Task<Void, Never> {
    Task {
      try? await Task.sleep(for: .seconds(3))
      await MainActor.run {
        if binding.wrappedValue == message {
          binding.wrappedValue = nil
        }
      }
    }
  }
}
```

**Usage:**
```swift
// Before (11 lines)
Task {
  try? await Task.sleep(for: .seconds(3))
  await MainActor.run {
    if successMessage == "Preferences saved successfully" {
      successMessage = nil
    }
  }
}

// After (1 line)
Task.clearSuccessMessage("Preferences saved successfully", binding: $successMessage)
```

**Impact:** Reduces 55 lines to 11 lines + 1 utility.

---

#### Refactoring 2: Standardize Load/Save Patterns
**Current:** Inconsistent method names and error handling

**Create:** `PreferenceLoadable` protocol

```swift
protocol PreferenceLoadable: ObservableObject {
  associatedtype PreferenceData: Codable

  var data: PreferenceData { get set }
  var isLoading: Bool { get set }
  var isSaving: Bool { get set }
  var errorMessage: String? { get set }
  var successMessage: String? { get set }
  var hasUnsavedChanges: Bool { get set }

  var preferenceService: PreferenceManaging { get }
  var category: PreferenceCategory { get }

  func load() async
  func save() async
}

extension PreferenceLoadable {
  func load() async {
    isLoading = true
    errorMessage = nil

    do {
      if let saved: PreferenceData = try await preferenceService.fetchPreferences(category: category) {
        data = saved
      }
      isLoading = false
    } catch {
      errorMessage = "Failed to load: \(error.localizedDescription)"
      isLoading = false
    }
  }

  func save() async {
    isSaving = true
    errorMessage = nil
    successMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: category, data: data)
      hasUnsavedChanges = false
      successMessage = "Saved successfully"
      Task.clearSuccessMessage("Saved successfully", binding: $successMessage)
      isSaving = false
    } catch {
      errorMessage = "Failed to save: \(error.localizedDescription)"
      isSaving = false
    }
  }
}
```

**Benefits:**
- Eliminates 150+ lines of duplicated load/save logic
- Consistent error handling across all ViewModels
- Easier to add new preference pages

**Trade-off:** Adds protocol complexity, but gains massive code reduction.

---

#### Refactoring 3: Extract `markChanged()` Utility
**Current:** 5 trivial methods (10 lines total)

**Solution:** Remove methods, inline `hasUnsavedChanges = true`

**Rationale:**
- Method adds no value (just wraps a single assignment)
- Direct assignment is clearer and more idiomatic SwiftUI
- Reduces method count without losing clarity

**Before:**
```swift
func markAsChanged() {
  hasUnsavedChanges = true
}

// Usage
updateCity("Springfield")
markChanged()
```

**After:**
```swift
// Direct usage
updateCity("Springfield")
hasUnsavedChanges = true
```

**Impact:** Removes 10 unnecessary lines.

---

### Phase 3: Standardize Naming Conventions (Low Effort, High Clarity)

#### Change Set

| ViewModel | Current Methods | Standardized Methods |
|-----------|----------------|---------------------|
| NotificationPreferencesViewModel | `loadPreferences()`, `savePreferences()` | ✅ Already consistent |
| HomeLocationViewModel | `loadLocation()`, `saveLocation()` | → `loadPreferences()`, `savePreferences()` |
| DashboardCustomizationViewModel | `loadVisibility()`, `saveVisibility()` | → `loadPreferences()`, `savePreferences()` |
| SchoolPreferencesViewModel | `loadPreferences()`, `savePreferences()` | ✅ Already consistent |
| PlayerDetailsViewModel | `loadDetails()`, `saveDetails()` | → `loadPreferences()`, `savePreferences()` |

**Rationale:**
- All pages manage "preferences" conceptually
- Consistent naming improves code scanability
- Easier for new developers to navigate

**Impact:** Minimal code change, significant clarity improvement.

---

### Phase 4: Extract Validation Utilities (Medium Priority)

#### Create: `PreferenceValidators.swift`

**Current Issues:**
- Input validation scattered across ViewModels
- No reusable validation logic
- Hard to test validation rules

**Proposed Utilities:**

```swift
enum PreferenceValidators {
  // Numeric range validation
  static func validateRange<T: Comparable>(
    _ value: T?,
    min: T,
    max: T
  ) -> T? {
    guard let value = value else { return nil }
    return (min...max).contains(value) ? value : nil
  }

  // String length validation
  static func limitLength(_ string: String, maxLength: Int) -> String {
    String(string.prefix(maxLength))
  }

  // State code validation
  static func formatStateCode(_ input: String) -> String {
    let uppercased = input.uppercased()
    return String(uppercased.prefix(2))
  }

  // GPA validation (0.0-5.0)
  static func validateGPA(_ gpa: Double?) -> Double? {
    validateRange(gpa, min: 0.0, max: 5.0)
  }

  // SAT validation (400-1600)
  static func validateSAT(_ sat: Int?) -> Int? {
    validateRange(sat, min: 400, max: 1600)
  }

  // ACT validation (1-36)
  static func validateACT(_ act: Int?) -> Int? {
    validateRange(act, min: 1, max: 36)
  }
}
```

**Benefits:**
- Testable validation logic
- Reusable across ViewModels
- Clear validation rules in one place

**Usage Example:**
```swift
// Before (PlayerDetailsViewModel.swift:154-162)
func updateSAT(_ value: Int?) {
  if let sat = value, sat >= 400 && sat <= 1600 {
    details.satScore = sat
    markChanged()
  } else if value == nil {
    details.satScore = nil
    markChanged()
  }
}

// After
func updateSAT(_ value: Int?) {
  details.satScore = PreferenceValidators.validateSAT(value)
  hasUnsavedChanges = true
}
```

---

### Phase 5: Optimize Auto-Save (Optional Enhancement)

**Current State:**
- Two ViewModels implement debounced auto-save
- Similar but not identical implementations
- Could be generalized

**Proposed:** Extract `AutoSavePublisher` utility (if needed in future)

**Decision:** **DEFER** until more ViewModels need auto-save.

**Rationale:**
- Only 2 ViewModels use auto-save currently
- Abstraction premature at this scale
- Re-evaluate if 3+ ViewModels need it

---

## 3. File Size Analysis

### Current File Sizes

| File | Lines | Status |
|------|-------|--------|
| NotificationPreferencesViewModel.swift | 96 | ✅ Under 200 |
| HomeLocationViewModel.swift | 219 | ✅ Under 400 |
| DashboardCustomizationViewModel.swift | 160 | ✅ Under 200 |
| SchoolPreferencesViewModel.swift | 263 | ✅ Under 400 |
| PlayerDetailsViewModel.swift | 226 | ✅ Under 400 |
| NotificationPreferencesView.swift | 151 | ✅ Under 200 |
| HomeLocationView.swift | 197 | ✅ Under 200 |
| PreferenceServiceImpl.swift | 276 | ✅ Under 400 |

**Result:** All files are within acceptable limits (200-400 typical, 800 max).

**Action:** No file splitting needed. Focus on reducing duplication.

---

## 4. Implementation Order

### Priority 1: UI Components (Highest ROI)
1. ✅ Extract `PreferenceLoadingOverlay`
2. ✅ Extract `PreferenceErrorAlert`
3. ✅ Extract `PreferenceSuccessToast`
4. ✅ Extract `PreferenceSaveButton`
5. ✅ Extract `PreferencePreviewMock`

**Impact:** Removes 300+ lines of duplication.

---

### Priority 2: ViewModel Utilities
1. ✅ Extract success message helper
2. ✅ Remove `markAsChanged()` methods
3. ✅ Standardize naming conventions

**Impact:** Removes 65+ lines, improves consistency.

---

### Priority 3: Validation (Optional)
1. ✅ Extract `PreferenceValidators`

**Impact:** Centralizes validation logic.

---

### Priority 4: Protocol-Based Refactoring (Advanced)
1. ⏸️ **DEFER** `PreferenceLoadable` protocol (evaluate after simpler refactorings)

**Rationale:** Adds complexity. Apply only if ViewModels remain too similar after Phase 1-3.

---

## 5. Testing Strategy

### Test Preservation
- ✅ All 125+ existing tests MUST pass after refactoring
- ✅ No behavioral changes to ViewModels or Views
- ✅ Run full test suite after each phase

### New Tests (if needed)
- ✅ Unit tests for `PreferenceValidators`
- ✅ Unit tests for success message helper
- ✅ Preview tests for extracted components

---

## 6. Risks & Mitigation

### Risk 1: Breaking Existing Tests
**Likelihood:** Medium
**Impact:** High
**Mitigation:** Run tests after EVERY extraction, not at end.

### Risk 2: Over-Abstraction
**Likelihood:** Low
**Impact:** Medium
**Mitigation:** Defer protocol-based refactoring until proven necessary.

### Risk 3: Naming Conflicts
**Likelihood:** Low
**Impact:** Low
**Mitigation:** Use clear, descriptive names for extracted components.

---

## 7. Success Criteria

### Code Quality Metrics
- ✅ Reduce duplication by 300+ lines
- ✅ All files under 400 lines (already achieved)
- ✅ Consistent naming conventions across ViewModels
- ✅ Protocol-based DI maintained
- ✅ All 125+ tests passing

### Code Patterns
- ✅ Shared UI components extracted
- ✅ Validation logic centralized
- ✅ Success message logic consolidated
- ✅ Error handling standardized

---

## 8. Final Notes

**Estimated Time:** 2-3 hours
**Risk Level:** Low (all changes are extractions/renames)
**Breaking Changes:** None (internal refactoring only)

**Next Steps:**
1. Get approval from team-lead
2. Execute Phase 1 (UI components)
3. Run tests
4. Execute Phase 2 (ViewModel utilities)
5. Run tests
6. Execute Phase 3 (naming standardization)
7. Run tests
8. Verify all 125+ tests pass
9. Mark Task #9 complete
10. Report refactoring summary to team

---

**Refactoring Specialist:** refactor-specialist
**Status:** Plan ready for review
