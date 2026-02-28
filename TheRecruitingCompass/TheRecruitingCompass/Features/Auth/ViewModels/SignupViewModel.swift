import Foundation
import OSLog
import SwiftUI
import Observation

private let signupLogger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SignupViewModel")

@Observable
@MainActor
final class SignupViewModel {
  // MARK: - Two-Step State

  var selectedRole: UserRole?
  var showForm = false

  // MARK: - Form Fields

  var fullName = ""
  var email = ""
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

  var isFormValid: Bool {
    guard let role = selectedRole else { return false }

    let hasValidFullName = !fullName.trimmingCharacters(in: .whitespaces).isEmpty
    let hasValidEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
    let hasValidPassword = !password.isEmpty
    let passwordsMatch = password == confirmPassword
    let termsChecked = termsAccepted
    let passwordStrengthValid = formValidator.validatePasswordStrength(password).isValid
    let noFieldErrors = fieldErrors.isEmpty

    let familyCodeValid = if role.requiresFamilyCode {
      familyCode.trimmingCharacters(in: .whitespaces).isEmpty ||
        formValidator.validateFamilyCode(familyCode) == nil
    } else {
      true
    }

    return hasValidFullName &&
      hasValidEmail &&
      hasValidPassword &&
      passwordsMatch &&
      termsChecked &&
      passwordStrengthValid &&
      familyCodeValid &&
      noFieldErrors
  }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
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
    fullName = ""
    email = ""
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

  func validateFullName() { validate(.fullName) { formValidator.validateName(fullName) } }
  func validateEmail() { validate(.email) { formValidator.validateEmail(email) } }

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

    validateFullName()
    validateEmail()
    validatePassword()
    validateConfirmPassword()
    validateFamilyCode()
    validateTerms()

    guard isFormValid else {
      errorMessage = "Please fix the errors above"
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
        familyCode: nil
      )

      // Create family for both roles (mirrors web: POST /api/family/create)
      if authManager.isAuthenticated {
        do {
          _ = try await familyService.createFamily(role: role)
        } catch {
          // Log but don't block signup; user can create family from Family Management
          signupLogger.warning("Family creation failed: \(error.localizedDescription)")
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

  nonisolated deinit {}
}
