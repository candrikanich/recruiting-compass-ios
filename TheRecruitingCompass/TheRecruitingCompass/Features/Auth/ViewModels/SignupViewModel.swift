import Foundation
import OSLog
import SwiftUI
import Observation

private let signupLogger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SignupViewModel")

@Observable
@MainActor
final class SignupViewModel {

  nonisolated deinit {}
  // MARK: - Two-Step State

  var selectedRole: UserRole?
  var showForm = false

  // MARK: - Form Fields

  var firstName = ""
  var lastName = ""
  var email = ""
  var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -15, to: .now) ?? .now
  var password = ""
  var confirmPassword = ""
  var familyCode = ""
  var termsAccepted = false

  // MARK: - UI State

  var isLoading = false
  var errorMessage: String?
  var fieldErrors: [FormFieldKey: String] = [:]
  var shouldNavigateToVerifyEmail = false

  private let authManager: any AuthManaging
  private let familyService: any FamilyManaging
  private let formValidator = FormValidator.self

  private var trimmedFirstName: String {
    firstName.trimmingCharacters(in: .whitespaces)
  }

  private var trimmedLastName: String {
    lastName.trimmingCharacters(in: .whitespaces)
  }

  /// Combined full name sent to the backend (Supabase `full_name`).
  /// Mirrors web behavior where first and last name fields are concatenated.
  var fullName: String {
    switch (trimmedFirstName.isEmpty, trimmedLastName.isEmpty) {
    case (false, false):
      return "\(trimmedFirstName) \(trimmedLastName)"
    case (false, true):
      return trimmedFirstName
    case (true, false):
      return trimmedLastName
    default:
      return ""
    }
  }

  private static let dobFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private var dobString: String {
    Self.dobFormatter.string(from: dateOfBirth)
  }

  var isFormValid: Bool {
    guard let role = selectedRole else { return false }

    let hasValidFirstName = !trimmedFirstName.isEmpty
    let hasValidLastName = !trimmedLastName.isEmpty
    let hasValidEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
    let hasValidPassword = !password.isEmpty
    let passwordsMatch = password == confirmPassword
    let termsChecked = termsAccepted
    let passwordStrengthValid = formValidator.validatePasswordStrength(password).isValid
    // DOB is only required for players (COPPA); parents don't provide their own DOB at signup.
    let hasValidDOB = role == .player
      ? !COPPAHelper.isUnderAge(dobString)
      : true
    let noFieldErrors = fieldErrors.isEmpty

    let familyCodeValid = if role.requiresFamilyCode {
      familyCode.trimmingCharacters(in: .whitespaces).isEmpty ||
        formValidator.validateFamilyCode(familyCode) == nil
    } else {
      true
    }

    return hasValidFirstName &&
      hasValidLastName &&
      hasValidEmail &&
      hasValidPassword &&
      passwordsMatch &&
      termsChecked &&
      passwordStrengthValid &&
      hasValidDOB &&
      familyCodeValid &&
      noFieldErrors
  }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
  }

  /// True when the player is under 13 (COPPA). Players 13+ can sign up independently.
  var isUnderCOPPAAge: Bool {
    selectedRole == .player && COPPAHelper.isUnderAge(dobString)
  }

  init(authManager: (any AuthManaging)? = nil, familyService: (any FamilyManaging)? = nil) {
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
  }

  // MARK: - Two-Step Flow

  func selectRole(_ role: UserRole) {
    selectedRole = role
    withAnimation { showForm = true }
  }

  func backToRoleSelection() {
    withAnimation { showForm = false }
    resetFormState()
  }

  private func resetFormState() {
    firstName = ""
    lastName = ""
    email = ""
    dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: .now) ?? .now
    password = ""
    confirmPassword = ""
    familyCode = ""
    termsAccepted = false
    fieldErrors = [:]
    errorMessage = nil
  }

  // MARK: - Validation

  private func validate(_ field: FormFieldKey, using validator: () -> String?) {
    fieldErrors[field] = validator()
  }

  func validateFirstName() { validate(.firstName) { formValidator.validateName(trimmedFirstName) } }
  func validateLastName() { validate(.lastName) { formValidator.validateName(trimmedLastName) } }
  func validateEmail() { validate(.email) { formValidator.validateEmail(email) } }

  func validateDateOfBirth() {
    validate(.dateOfBirth) {
      if COPPAHelper.isUnderAge(dobString) {
        return "You must be 13 or older to create an account"
      }
      return nil
    }
  }

  func validatePassword() {
    validate(.password) {
      formValidator.validatePasswordStrength(password).isValid
        ? nil
        : "Password does not meet strength requirements"
    }
  }

  func validateConfirmPassword() {
    validate(.confirmPassword) { formValidator.validatePasswordMatch(password, confirmPassword) }
  }

  func validateFamilyCode() {
    guard let role = selectedRole, role.requiresFamilyCode else {
      fieldErrors[.familyCode] = nil
      return
    }
    validate(.familyCode) { formValidator.validateFamilyCode(familyCode) }
  }

  func errorBinding(for key: FormFieldKey) -> Binding<String?> {
    Binding(
      get: { self.fieldErrors[key] },
      set: { self.fieldErrors[key] = $0 }
    )
  }

  func validateTerms() {
    if !termsAccepted {
      errorMessage = "You must accept the terms and conditions"
    } else {
      errorMessage = nil
    }
  }

  // MARK: - Actions

  func signup() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    validateFirstName()
    validateLastName()
    validateEmail()
    if selectedRole == .player { validateDateOfBirth() }
    validatePassword()
    validateConfirmPassword()
    validateFamilyCode()

    guard isFormValid else {
      if !fieldErrors.isEmpty {
        errorMessage = "Please fix the errors below"
      } else if !termsAccepted {
        errorMessage = "You must accept the terms and conditions"
      } else {
        errorMessage = "Please fix the errors below"
      }
      return
    }

    guard let role = selectedRole else {
      errorMessage = "Please select a role"
      return
    }

    do {
      try await authManager.signup(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        familyCode: nil,
        dateOfBirth: role == .player ? dobString : nil
      )

      // Create family for both roles (mirrors web: POST /api/family/create)
      if authManager.isAuthenticated {
        do {
          _ = try await familyService.createFamily(role: role)
        } catch {
          // intentionally silent: signup itself succeeded and must not be blocked.
          // The dashboard onboarding banner detects the missing family and walks
          // the user through creating one, so that is the recovery surface.
          signupLogger.error("Family creation failed during signup: \(error.localizedDescription)")
        }
      }

      // Only show email verification when no session (e.g. confirmation required)
      if !authManager.isAuthenticated {
        shouldNavigateToVerifyEmail = true
      }
    } catch {
      errorMessage = mapAuthError(error).userMessage
    }
  }

  func dismissError() {
    errorMessage = nil
  }

}
