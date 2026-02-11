# Implementation Plan: Add Coach Feature

**Created:** February 10, 2026
**Spec:** iOS_SPEC_Phase3_AddCoach.md
**Feature:** Add Coach (Two-Step Form Flow)
**Estimated Time:** 4-5 days
**Priority:** High (Core MVP Feature)

---

## Executive Summary

Implement a two-step form flow to add new coaches to tracked schools:
1. **Step 1:** Select a school from user's tracked schools
2. **Step 2:** Fill out coach form with role, contact info, social handles, and notes

On success, navigate to the newly created coach's detail page. This establishes reusable validation patterns for future forms (Add School, Add Interaction, Edit modals).

---

## Current State Analysis

### ✅ Already Implemented
- ✅ Coach model (`Features/Dashboard/Models/Coach.swift`)
- ✅ CoachRole enum (`Features/Coaches/Models/CoachRole.swift`)
- ✅ School model (`Features/Dashboard/Models/School.swift`)
- ✅ CoachesService with protocol (`CoachesServiceImpl`, `CoachesManaging`)
- ✅ CoachesService.fetchSchools() - fetches schools by family_unit_id
- ✅ MVVM architecture patterns established
- ✅ Accessibility patterns from Login/Signup features
- ✅ Dynamic Type support patterns

### ❌ Not Yet Implemented
- ❌ `CoachesManaging.createCoach()` method
- ❌ AddCoachView (two-step form)
- ❌ AddCoachViewModel (form state + validation)
- ❌ CoachFormView (reusable form component)
- ❌ Field validators (email, phone, social handles)
- ❌ CoachCreateRequest model
- ❌ SchoolPicker component
- ❌ FormErrorSummary component
- ❌ FieldError component

---

## Implementation Phases

### Phase 1: Foundation (Day 1, ~4 hours)

#### 1.1 Create Data Models

**File:** `Features/Coaches/Models/CoachCreateRequest.swift`
```swift
struct CoachCreateRequest: Encodable, Sendable {
  let schoolId: String
  let userId: String
  let familyUnitId: String
  let role: String
  let firstName: String
  let lastName: String
  let email: String?
  let phone: String?
  let twitterHandle: String?
  let instagramHandle: String?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case schoolId = "school_id"
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case role
    case firstName = "first_name"
    case lastName = "last_name"
    case email, phone
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case notes
  }
}
```

**File:** `Features/Coaches/Models/CoachFormState.swift`
```swift
struct CoachFormState: Sendable {
  var selectedSchoolId: String?
  var role: CoachRole?
  var firstName: String
  var lastName: String
  var email: String
  var phone: String
  var twitterHandle: String
  var instagramHandle: String
  var notes: String

  var isSchoolSelected: Bool { selectedSchoolId != nil }

  var isSubmittable: Bool {
    isSchoolSelected &&
    role != nil &&
    !firstName.isEmpty &&
    !lastName.isEmpty
  }

  init() {
    self.selectedSchoolId = nil
    self.role = nil
    self.firstName = ""
    self.lastName = ""
    self.email = ""
    self.phone = ""
    self.twitterHandle = ""
    self.instagramHandle = ""
    self.notes = ""
  }
}
```

**File:** `Features/Coaches/Models/CoachFormErrors.swift`
```swift
struct CoachFormErrors: Sendable {
  var role: String?
  var firstName: String?
  var lastName: String?
  var email: String?
  var phone: String?
  var twitterHandle: String?
  var instagramHandle: String?
  var notes: String?

  var hasErrors: Bool {
    [role, firstName, lastName, email, phone,
     twitterHandle, instagramHandle, notes]
      .contains(where: { $0 != nil })
  }

  var allErrors: [String] {
    [role, firstName, lastName, email, phone,
     twitterHandle, instagramHandle, notes]
      .compactMap { $0 }
  }

  static let empty = CoachFormErrors()
}
```

#### 1.2 Update CoachesManaging Protocol

**File:** `Features/Coaches/Services/CoachesManaging.swift`
```swift
protocol CoachesManaging: Sendable {
  // Existing methods...
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func updateCoach(id: String, updates: CoachUpdateRequest) async throws -> Coach
  func fetchInteractions(coachId: String, limit: Int) async throws -> [Interaction]
  func deleteCoach(id: String) async throws
  func cascadeDeleteCoach(id: String) async throws -> DeleteResult

  // NEW: Create coach
  func createCoach(request: CoachCreateRequest) async throws -> Coach
}
```

#### 1.3 Implement createCoach in CoachesServiceImpl

**File:** `Features/Coaches/Services/CoachesServiceImpl.swift`
```swift
func createCoach(request: CoachCreateRequest) async throws -> Coach {
  logger.debug("Creating coach: \(request.firstName) \(request.lastName)")

  let result: Coach = try await supabaseManager.client
    .from("coaches")
    .insert(request)
    .select()
    .single()
    .execute()
    .value

  logger.info("Coach created: \(result.id)")
  return result
}
```

**Testing:**
- Unit tests for CoachesServiceImpl.createCoach()
- Mock Supabase responses
- Verify request encoding (snake_case fields)

---

### Phase 2: Validation System (Day 1-2, ~6 hours)

Create reusable validators following web app patterns.

#### 2.1 Create Field Validators

**File:** `Shared/Utilities/Validators/FieldValidator.swift`
```swift
enum FieldValidator {

  static func validateRole(_ role: CoachRole?) -> String? {
    guard role != nil else { return "Please select a role" }
    return nil
  }

  static func validateFirstName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "First name is required" }
    if trimmed.count > 100 { return "First name must not exceed 100 characters" }
    return nil
  }

  static func validateLastName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "Last name is required" }
    if trimmed.count > 100 { return "Last name must not exceed 100 characters" }
    return nil
  }

  static func validateEmail(_ email: String) -> String? {
    guard !email.isEmpty else { return nil }  // optional field
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if trimmed.count < 5 { return "Email must be at least 5 characters" }
    if trimmed.count > 255 { return "Email must not exceed 255 characters" }
    let emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
    if trimmed.wholeMatch(of: emailRegex) == nil {
      return "Please enter a valid email address"
    }
    return nil
  }

  static func validatePhone(_ phone: String) -> String? {
    guard !phone.isEmpty else { return nil }  // optional field
    let phoneRegex = /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/
    if phone.wholeMatch(of: phoneRegex) == nil {
      return "Please enter a valid phone number"
    }
    return nil
  }

  static func validateTwitterHandle(_ handle: String) -> String? {
    guard !handle.isEmpty else { return nil }  // optional field
    let cleaned = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
    let twitterRegex = /^[A-Za-z0-9_]{1,15}$/
    if cleaned.wholeMatch(of: twitterRegex) == nil {
      return "Invalid Twitter handle (1-15 characters, letters/numbers/underscore)"
    }
    return nil
  }

  static func validateInstagramHandle(_ handle: String) -> String? {
    guard !handle.isEmpty else { return nil }  // optional field
    let cleaned = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
    let instagramRegex = /^[A-Za-z0-9_.]{1,30}$/
    if cleaned.wholeMatch(of: instagramRegex) == nil {
      return "Invalid Instagram handle (1-30 characters, letters/numbers/dots/underscore)"
    }
    return nil
  }

  static func validateNotes(_ notes: String) -> String? {
    guard !notes.isEmpty else { return nil }  // optional field
    if notes.count > 5000 { return "Notes must not exceed 5000 characters" }
    return nil
  }

  static func validateAllCoachFields(_ form: CoachFormState) -> CoachFormErrors {
    CoachFormErrors(
      role: validateRole(form.role),
      firstName: validateFirstName(form.firstName),
      lastName: validateLastName(form.lastName),
      email: validateEmail(form.email),
      phone: validatePhone(form.phone),
      twitterHandle: validateTwitterHandle(form.twitterHandle),
      instagramHandle: validateInstagramHandle(form.instagramHandle),
      notes: validateNotes(form.notes)
    )
  }
}
```

#### 2.2 Create Data Sanitizers

**File:** `Shared/Utilities/Validators/DataSanitizer.swift`
```swift
enum DataSanitizer {

  /// Convert empty string to nil
  static func nilIfEmpty(_ value: String) -> String? {
    value.isEmpty ? nil : value
  }

  /// Strip leading @ from social handles
  static func stripAtSign(_ handle: String) -> String {
    handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
  }

  /// Strip HTML tags from text (basic implementation)
  static func stripHtmlTags(_ text: String) -> String {
    text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
  }

  /// Prepare coach data for submission
  static func prepareCoachData(
    form: CoachFormState,
    schoolId: String,
    userId: String,
    familyUnitId: String
  ) -> CoachCreateRequest {
    CoachCreateRequest(
      schoolId: schoolId,
      userId: userId,
      familyUnitId: familyUnitId,
      role: form.role!.rawValue,
      firstName: form.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
      lastName: form.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
      email: nilIfEmpty(form.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
      phone: nilIfEmpty(form.phone),
      twitterHandle: nilIfEmpty(stripAtSign(form.twitterHandle)),
      instagramHandle: nilIfEmpty(stripAtSign(form.instagramHandle)),
      notes: nilIfEmpty(stripHtmlTags(form.notes))
    )
  }
}
```

**Testing:**
- Unit tests for all validators (valid, invalid, edge cases)
- Unit tests for sanitizers (@ stripping, empty → nil, HTML stripping)

---

### Phase 3: ViewModel (Day 2, ~4 hours)

#### 3.1 Create AddCoachViewModel

**File:** `Features/Coaches/ViewModels/AddCoachViewModel.swift`
```swift
import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "AddCoachViewModel")

@MainActor
final class AddCoachViewModel: ObservableObject {

  // MARK: - Published State

  @Published var formState = CoachFormState()
  @Published var formErrors = CoachFormErrors.empty
  @Published var schools: [School] = []
  @Published var isLoadingSchools = false
  @Published var isSubmitting = false
  @Published var submitError: String?

  // MARK: - Dependencies

  private let coachesService: CoachesManaging
  private let familyUnitId: String
  private let userId: String

  // MARK: - Computed Properties

  var isFormVisible: Bool {
    formState.isSchoolSelected
  }

  var isSubmitDisabled: Bool {
    isSubmitting || formErrors.hasErrors || !formState.isSubmittable
  }

  var submitButtonTitle: String {
    isSubmitting ? "Adding..." : "Add Coach"
  }

  // MARK: - Init

  init(
    coachesService: CoachesManaging,
    familyUnitId: String,
    userId: String
  ) {
    self.coachesService = coachesService
    self.familyUnitId = familyUnitId
    self.userId = userId
  }

  // MARK: - Actions

  func loadSchools() async {
    guard !isLoadingSchools else { return }

    isLoadingSchools = true
    defer { isLoadingSchools = false }

    do {
      schools = try await coachesService.fetchSchools(familyUnitId: familyUnitId)
      logger.info("Loaded \(self.schools.count) schools")
    } catch {
      logger.error("Failed to load schools: \(error.localizedDescription)")
      submitError = "Failed to load schools. Please try again."
    }
  }

  func validateField(_ field: KeyPath<CoachFormState, String>, value: String) {
    // Field-level validation on blur
    switch field {
    case \.firstName:
      formErrors.firstName = FieldValidator.validateFirstName(value)
    case \.lastName:
      formErrors.lastName = FieldValidator.validateLastName(value)
    case \.email:
      formErrors.email = FieldValidator.validateEmail(value)
    case \.phone:
      formErrors.phone = FieldValidator.validatePhone(value)
    case \.twitterHandle:
      formErrors.twitterHandle = FieldValidator.validateTwitterHandle(value)
    case \.instagramHandle:
      formErrors.instagramHandle = FieldValidator.validateInstagramHandle(value)
    case \.notes:
      formErrors.notes = FieldValidator.validateNotes(value)
    default:
      break
    }
  }

  func validateRole(_ role: CoachRole?) {
    formErrors.role = FieldValidator.validateRole(role)
  }

  func submitCoach() async -> Coach? {
    // 1. Full validation
    formErrors = FieldValidator.validateAllCoachFields(formState)

    guard !formErrors.hasErrors else {
      logger.warning("Validation failed: \(self.formErrors.allErrors)")
      announceErrorsForAccessibility()
      return nil
    }

    guard let schoolId = formState.selectedSchoolId else {
      logger.error("No school selected")
      return nil
    }

    // 2. Prepare data
    let request = DataSanitizer.prepareCoachData(
      form: formState,
      schoolId: schoolId,
      userId: userId,
      familyUnitId: familyUnitId
    )

    // 3. Submit
    isSubmitting = true
    submitError = nil
    defer { isSubmitting = false }

    do {
      let newCoach = try await coachesService.createCoach(request: request)
      logger.info("Coach created: \(newCoach.id)")

      // Success haptic
      let generator = UINotificationFeedbackGenerator()
      generator.notificationOccurred(.success)

      return newCoach

    } catch {
      logger.error("Failed to create coach: \(error.localizedDescription)")
      submitError = "Failed to create coach. Please try again."

      // Error haptic
      let generator = UINotificationFeedbackGenerator()
      generator.notificationOccurred(.error)

      return nil
    }
  }

  private func announceErrorsForAccessibility() {
    let announcement = "Form has \(formErrors.allErrors.count) errors: \(formErrors.allErrors.joined(separator: ", "))"
    UIAccessibility.post(notification: .announcement, argument: announcement)
  }
}
```

**Testing:**
- Unit tests for loadSchools (success, error)
- Unit tests for validateField (each field)
- Unit tests for submitCoach (success, validation error, network error)
- Test computed properties (isSubmitDisabled, etc.)

---

### Phase 4: Reusable Components (Day 2-3, ~6 hours)

#### 4.1 SchoolPicker Component

**File:** `Shared/Components/Forms/SchoolPicker.swift`
```swift
import SwiftUI

struct SchoolPicker: View {
  @Binding var selectedSchoolId: String?
  let schools: [School]
  let isDisabled: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("School")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)

        Spacer()
      }

      Picker("Select School", selection: $selectedSchoolId) {
        Text("Select School")
          .tag(nil as String?)

        ForEach(schools) { school in
          Text(school.name)
            .tag(school.id as String?)
        }
      }
      .pickerStyle(.menu)
      .disabled(isDisabled)
      .accessibilityLabel("School, required")
      .accessibilityHint("Select a school to add a coach to")
    }
  }
}
```

#### 4.2 FormErrorSummary Component

**File:** `Shared/Components/Forms/FormErrorSummary.swift`
```swift
import SwiftUI

struct FormErrorSummary: View {
  let errors: [String]
  let onDismiss: () -> Void

  var body: some View {
    if !errors.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.white)
            .accessibilityHidden(true)

          Text("Please fix the following errors:")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)

          Spacer()

          Button {
            onDismiss()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.white.opacity(0.7))
          }
          .accessibilityLabel("Dismiss error summary")
        }

        VStack(alignment: .leading, spacing: 6) {
          ForEach(errors, id: \.self) { error in
            HStack(alignment: .top, spacing: 8) {
              Text("•")
                .foregroundStyle(.white)
                .accessibilityHidden(true)

              Text(error)
                .font(.caption)
                .foregroundStyle(.white)
            }
          }
        }
      }
      .padding()
      .background(Color.red)
      .cornerRadius(12)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Form errors")
      .accessibilityValue("\(errors.count) errors: \(errors.joined(separator: ", "))")
      .accessibilityAddTraits(.updatesFrequently)
    }
  }
}
```

#### 4.3 FieldError Component

**File:** `Shared/Components/Forms/FieldError.swift`
```swift
import SwiftUI

struct FieldError: View {
  let error: String?

  var body: some View {
    if let error {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.red)
          .accessibilityHidden(true)

        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Error: \(error)")
    }
  }
}
```

#### 4.4 CoachFormView Component

**File:** `Features/Coaches/Components/CoachFormView.swift`

This is a large component - see Appendix A for full implementation. Key features:
- Role picker (required)
- First/last name (side-by-side on iPad, stacked on iPhone)
- Email/phone fields with appropriate keyboards
- Twitter/Instagram handles (auto-strip @ on blur)
- Notes text editor with character count
- Field-level validation on blur
- Accessibility labels and hints

**Testing:**
- Accessibility tests for all components
- Dynamic Type tests
- Hit target tests (44x44 minimum)

---

### Phase 5: Main View (Day 3-4, ~6 hours)

#### 5.1 Create AddCoachView

**File:** `Features/Coaches/Views/AddCoachView.swift`

```swift
import SwiftUI

struct AddCoachView: View {
  @StateObject private var viewModel: AddCoachViewModel
  @Environment(\.dismiss) private var dismiss
  @FocusState private var focusedField: Field?

  enum Field: Hashable {
    case firstName, lastName, email, phone, twitter, instagram, notes
  }

  init(
    coachesService: CoachesManaging,
    familyUnitId: String,
    userId: String
  ) {
    _viewModel = StateObject(wrappedValue: AddCoachViewModel(
      coachesService: coachesService,
      familyUnitId: familyUnitId,
      userId: userId
    ))
  }

  var body: some View {
    NavigationStack {
      Form {
        // Section 1: School Selection
        Section {
          if viewModel.isLoadingSchools {
            HStack {
              ProgressView()
              Text("Loading schools...")
                .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Loading schools")
          } else if viewModel.schools.isEmpty {
            emptySchoolsView
          } else {
            SchoolPicker(
              selectedSchoolId: $viewModel.formState.selectedSchoolId,
              schools: viewModel.schools,
              isDisabled: viewModel.isSubmitting
            )
            .onChange(of: viewModel.formState.selectedSchoolId) { _ in
              announceSchoolSelection()
            }
          }
        }

        // Section 2: Coach Form (visible when school selected)
        if viewModel.isFormVisible {
          Section {
            // Error summary
            if viewModel.formErrors.hasErrors {
              FormErrorSummary(
                errors: viewModel.formErrors.allErrors,
                onDismiss: { /* clear errors */ }
              )
            }

            CoachFormView(
              formState: $viewModel.formState,
              formErrors: $viewModel.formErrors,
              isDisabled: viewModel.isSubmitting,
              focusedField: $focusedField,
              onValidateField: viewModel.validateField,
              onValidateRole: viewModel.validateRole
            )
          }

          // Section 3: Actions
          Section {
            Button {
              Task {
                if let newCoach = await viewModel.submitCoach() {
                  // Navigate to coach detail
                  // TODO: Replace with proper navigation
                  dismiss()
                }
              }
            } label: {
              HStack {
                Spacer()
                if viewModel.isSubmitting {
                  ProgressView()
                    .progressViewStyle(.circular)
                }
                Text(viewModel.submitButtonTitle)
                  .fontWeight(.semibold)
                Spacer()
              }
            }
            .disabled(viewModel.isSubmitDisabled)
            .accessibilityLabel(viewModel.submitButtonTitle)
            .accessibilityHint(viewModel.isSubmitDisabled ? "Fill all required fields to enable" : "Create new coach")

            Button("Cancel", role: .cancel) {
              dismiss()
            }
            .accessibilityLabel("Cancel adding coach")
            .accessibilityHint("Return to coaches list without saving")
          }
        } else {
          // Prompt to select school
          Section {
            HStack(spacing: 12) {
              Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

              Text("Please select a school to continue")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Please select a school to continue adding a coach")
          }
        }
      }
      .navigationTitle("Add Coach")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Back") {
            dismiss()
          }
          .accessibilityLabel("Back to coaches list")
        }
      }
      .task {
        await viewModel.loadSchools()
      }
      .alert("Error", isPresented: .constant(viewModel.submitError != nil)) {
        Button("OK") {
          viewModel.submitError = nil
        }
      } message: {
        if let error = viewModel.submitError {
          Text(error)
        }
      }
    }
  }

  // MARK: - Empty State

  private var emptySchoolsView: some View {
    VStack(spacing: 16) {
      Image(systemName: "building.2.fill")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      VStack(spacing: 4) {
        Text("No Schools Found")
          .font(.headline)
          .foregroundStyle(.primary)

        Text("You need to add a school before adding a coach")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Button {
        // Navigate to Add School
        // TODO: Replace with proper navigation
      } label: {
        Label("Add School", systemImage: "plus.circle.fill")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityLabel("Add a school")
      .accessibilityHint("Navigate to add school page")
    }
    .padding()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No schools found. Add a school first.")
  }

  // MARK: - Accessibility

  private func announceSchoolSelection() {
    guard let schoolId = viewModel.formState.selectedSchoolId,
          let school = viewModel.schools.first(where: { $0.id == schoolId }) else {
      return
    }

    let announcement = "School selected. \(school.name). Coach form now available."
    UIAccessibility.post(notification: .announcement, argument: announcement)
  }
}
```

**Testing:**
- UI tests for two-step flow
- Accessibility tests (VoiceOver, Dynamic Type)
- Edge case tests (no schools, network errors)

---

### Phase 6: Integration & Navigation (Day 4, ~3 hours)

#### 6.1 Update CoachDestination

**File:** `Features/Coaches/Models/CoachDestination.swift`
```swift
enum CoachDestination: Hashable, Sendable {
  case detail(id: String)
  case add  // NEW
}
```

#### 6.2 Update CoachesListView Navigation

**File:** `Features/Coaches/Views/CoachesListView.swift`

Add navigation:
```swift
.toolbar {
  ToolbarItem(placement: .primaryAction) {
    Button {
      // Navigate to AddCoachView
      // Implementation depends on navigation pattern
    } label: {
      Image(systemName: "plus")
    }
    .accessibilityLabel("Add coach")
  }
}
```

#### 6.3 Wire Up Navigation Stack

Update navigation to handle `.add` destination:
```swift
NavigationStack(path: $path) {
  CoachesListView(...)
    .navigationDestination(for: CoachDestination.self) { destination in
      switch destination {
      case .detail(let id):
        CoachDetailView(coachId: id, ...)
      case .add:
        AddCoachView(
          coachesService: coachesService,
          familyUnitId: familyUnitId,
          userId: userId
        )
      }
    }
}
```

---

### Phase 7: Testing (Day 4-5, ~8 hours)

#### 7.1 Unit Tests
- ✅ CoachFormState tests
- ✅ CoachFormErrors tests
- ✅ FieldValidator tests (all fields, all scenarios)
- ✅ DataSanitizer tests (@ stripping, empty → nil, HTML stripping)
- ✅ AddCoachViewModel tests (loadSchools, validateField, submitCoach)
- ✅ CoachesServiceImpl.createCoach tests

#### 7.2 Integration Tests
- ✅ Full form submission flow
- ✅ Validation error handling
- ✅ Network error handling
- ✅ Success navigation

#### 7.3 Accessibility Tests
- ✅ VoiceOver labels for all fields
- ✅ Dynamic Type support
- ✅ Touch targets (44x44 minimum)
- ✅ Error announcements
- ✅ Focus management

#### 7.4 E2E Tests (Optional)
- ✅ Add coach happy path
- ✅ Validation errors
- ✅ No schools empty state
- ✅ Cancel flow

---

## File Structure

```
Features/Coaches/
├── Models/
│   ├── Coach.swift (existing)
│   ├── CoachRole.swift (existing)
│   ├── CoachFormState.swift (NEW)
│   ├── CoachFormErrors.swift (NEW)
│   ├── CoachCreateRequest.swift (NEW)
│   └── CoachDestination.swift (UPDATE)
├── ViewModels/
│   └── AddCoachViewModel.swift (NEW)
├── Views/
│   ├── CoachesListView.swift (UPDATE)
│   └── AddCoachView.swift (NEW)
├── Components/
│   └── CoachFormView.swift (NEW)
└── Services/
    ├── CoachesManaging.swift (UPDATE)
    └── CoachesServiceImpl.swift (UPDATE)

Shared/Components/Forms/
├── SchoolPicker.swift (NEW)
├── FormErrorSummary.swift (NEW)
└── FieldError.swift (NEW)

Shared/Utilities/Validators/
├── FieldValidator.swift (NEW)
└── DataSanitizer.swift (NEW)
```

---

## Reusability Strategy

This implementation creates reusable patterns for future forms:

### Reusable Components
1. **SchoolPicker** - Can be used in Add Interaction, Edit Coach
2. **FormErrorSummary** - Can be used in Add School, Add Interaction
3. **FieldError** - Can be used in all forms
4. **FieldValidator** - Email, phone, social handle validators reusable
5. **DataSanitizer** - @ stripping, HTML stripping reusable

### Reusable Patterns
1. **Two-step form flow** - Select prerequisite entity, then show form (reuse in Add Interaction)
2. **Field-level validation** - Validate on blur, show inline errors
3. **Form-level validation** - Validate all on submit, show summary
4. **Empty state handling** - No prerequisite entities (schools, coaches)
5. **Accessibility patterns** - VoiceOver, Dynamic Type, announcements

---

## Risk Assessment

### Medium Risks
1. **Form complexity** - 8 fields, multiple validation rules
   - **Mitigation:** Reuse Login/Signup validation patterns, test thoroughly

2. **Two-step flow UX** - School selection before form
   - **Mitigation:** Follow web app pattern, announce state changes for accessibility

### Low Risks
1. **Navigation** - New destination type
   - **Mitigation:** Follow existing CoachDestination pattern

2. **Service integration** - New createCoach method
   - **Mitigation:** Follow existing service patterns (fetchCoaches, updateCoach)

---

## Dependencies

### Internal
- ✅ Coach model (existing)
- ✅ School model (existing)
- ✅ CoachRole enum (existing)
- ✅ CoachesService (existing, needs createCoach method)
- ✅ FamilyManager (for familyUnitId, userId)

### External
- ✅ Supabase iOS SDK (already integrated)
- ✅ SwiftUI (iOS 16+)

---

## Success Metrics

1. ✅ All 8 form fields validate correctly
2. ✅ Social handles auto-strip @ on blur
3. ✅ Empty optional fields convert to null in database
4. ✅ On success, navigates to coach detail page
5. ✅ 100% accessibility coverage (VoiceOver, Dynamic Type)
6. ✅ 80%+ test coverage (unit + integration)
7. ✅ No build errors, no warnings
8. ✅ Reusable validation patterns established

---

## Appendix A: CoachFormView Full Implementation

**File:** `Features/Coaches/Components/CoachFormView.swift`

```swift
import SwiftUI

struct CoachFormView: View {
  @Binding var formState: CoachFormState
  @Binding var formErrors: CoachFormErrors
  let isDisabled: Bool
  var focusedField: FocusState<AddCoachView.Field?>.Binding
  let onValidateField: (KeyPath<CoachFormState, String>, String) -> Void
  let onValidateRole: (CoachRole?) -> Void

  var body: some View {
    VStack(spacing: 24) {
      // Role Picker
      rolePicker

      // Name Fields
      nameFields

      // Contact Info
      emailField
      phoneField

      // Social Media
      socialMediaFields

      // Notes
      notesField
    }
  }

  // MARK: - Role Picker

  private var rolePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Role")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)

        Spacer()
      }

      Picker("Role", selection: $formState.role) {
        Text("Select Role")
          .tag(nil as CoachRole?)

        ForEach(CoachRole.allCases, id: \.self) { role in
          Text(role.displayName)
            .tag(role as CoachRole?)
        }
      }
      .pickerStyle(.menu)
      .disabled(isDisabled)
      .onChange(of: formState.role) { newRole in
        onValidateRole(newRole)
      }
      .accessibilityLabel("Role, required")
      .accessibilityHint("Select the coach's role")

      FieldError(error: formErrors.role)
    }
  }

  // MARK: - Name Fields

  @ViewBuilder
  private var nameFields: some View {
    // Use HStack on iPad, VStack on iPhone
    ViewThatFits {
      HStack(spacing: 16) {
        firstNameField
        lastNameField
      }

      VStack(spacing: 16) {
        firstNameField
        lastNameField
      }
    }
  }

  private var firstNameField: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("First Name")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)
      }

      TextField("e.g., John", text: $formState.firstName)
        .textFieldStyle(.roundedBorder)
        .textContentType(.givenName)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused(focusedField, equals: .firstName)
        .onSubmit {
          onValidateField(\.firstName, formState.firstName)
        }
        .accessibilityLabel("First name, required")
        .accessibilityHint("Enter coach's first name")

      FieldError(error: formErrors.firstName)
    }
  }

  private var lastNameField: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Last Name")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)

        Text("*")
          .font(.subheadline)
          .foregroundStyle(.red)
          .accessibilityHidden(true)
      }

      TextField("e.g., Smith", text: $formState.lastName)
        .textFieldStyle(.roundedBorder)
        .textContentType(.familyName)
        .autocapitalization(.words)
        .disabled(isDisabled)
        .focused(focusedField, equals: .lastName)
        .onSubmit {
          onValidateField(\.lastName, formState.lastName)
        }
        .accessibilityLabel("Last name, required")
        .accessibilityHint("Enter coach's last name")

      FieldError(error: formErrors.lastName)
    }
  }

  // MARK: - Contact Info

  private var emailField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Email")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      TextField("john.smith@university.edu", text: $formState.email)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused(focusedField, equals: .email)
        .onSubmit {
          onValidateField(\.email, formState.email)
        }
        .accessibilityLabel("Email, optional")
        .accessibilityHint("Enter coach's email address")

      FieldError(error: formErrors.email)
    }
  }

  private var phoneField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Phone")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      TextField("(555) 123-4567", text: $formState.phone)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.phonePad)
        .textContentType(.telephoneNumber)
        .disabled(isDisabled)
        .focused(focusedField, equals: .phone)
        .onChange(of: focusedField.wrappedValue) { newFocus in
          if newFocus != .phone {
            onValidateField(\.phone, formState.phone)
          }
        }
        .accessibilityLabel("Phone, optional")
        .accessibilityHint("Enter coach's phone number")

      FieldError(error: formErrors.phone)
    }
  }

  // MARK: - Social Media

  @ViewBuilder
  private var socialMediaFields: some View {
    ViewThatFits {
      HStack(spacing: 16) {
        twitterField
        instagramField
      }

      VStack(spacing: 16) {
        twitterField
        instagramField
      }
    }
  }

  private var twitterField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Twitter Handle")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      TextField("@handle", text: $formState.twitterHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused(focusedField, equals: .twitter)
        .onSubmit {
          onValidateField(\.twitterHandle, formState.twitterHandle)
        }
        .accessibilityLabel("Twitter handle, optional")
        .accessibilityHint("Enter coach's Twitter handle")

      FieldError(error: formErrors.twitterHandle)
    }
  }

  private var instagramField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Instagram Handle")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      TextField("@handle", text: $formState.instagramHandle)
        .textFieldStyle(.roundedBorder)
        .autocapitalization(.none)
        .disabled(isDisabled)
        .focused(focusedField, equals: .instagram)
        .onSubmit {
          onValidateField(\.instagramHandle, formState.instagramHandle)
        }
        .accessibilityLabel("Instagram handle, optional")
        .accessibilityHint("Enter coach's Instagram handle")

      FieldError(error: formErrors.instagramHandle)
    }
  }

  // MARK: - Notes

  private var notesField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Notes")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      ZStack(alignment: .topLeading) {
        if formState.notes.isEmpty {
          Text("Any notes about this coach...")
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }

        TextEditor(text: $formState.notes)
          .frame(minHeight: 100)
          .disabled(isDisabled)
          .focused(focusedField, equals: .notes)
          .onChange(of: focusedField.wrappedValue) { newFocus in
            if newFocus != .notes {
              onValidateField(\.notes, formState.notes)
            }
          }
      }
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
      }
      .accessibilityLabel("Notes, optional")
      .accessibilityHint("Enter any notes about this coach")

      HStack {
        Spacer()
        Text("\(formState.notes.count) / 5000")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      FieldError(error: formErrors.notes)
    }
  }
}
```

---

## Appendix B: Testing Strategy

### Unit Test Files

1. **CoachFormStateTests.swift**
   - Test initialization
   - Test isSchoolSelected
   - Test isSubmittable

2. **CoachFormErrorsTests.swift**
   - Test hasErrors
   - Test allErrors
   - Test empty state

3. **FieldValidatorTests.swift**
   - Test each validator (valid, invalid, edge cases)
   - Test validateAllCoachFields

4. **DataSanitizerTests.swift**
   - Test nilIfEmpty
   - Test stripAtSign
   - Test stripHtmlTags
   - Test prepareCoachData

5. **AddCoachViewModelTests.swift**
   - Test loadSchools (success, error)
   - Test validateField (each field)
   - Test validateRole
   - Test submitCoach (success, validation error, network error)
   - Test computed properties

6. **CoachesServiceImplTests.swift**
   - Test createCoach (success, error)
   - Test request encoding

### Accessibility Test Files

1. **AddCoachAccessibilityTests.swift**
   - VoiceOver labels
   - Required field announcements
   - Dynamic Type support
   - Touch targets
   - Error announcements
   - Focus management

---

## Sign-Off

**Plan Created By:** Claude Code
**Plan Reviewed By:** Pending
**Ready for Implementation:** Yes
**Estimated Time:** 4-5 days
**Dependencies:** None blocking

**Next Steps:**
1. Review plan with Chris
2. Begin Phase 1: Foundation (Day 1)
3. Daily stand-up to review progress
4. Code review before merging
