import Foundation
import SwiftUI
import Combine

@MainActor
class SignupViewModel: ObservableObject {
  // MARK: - Two-Step State

  @Published var selectedRole: UserRole?
  @Published var showForm = false

  // MARK: - Form Fields

  @Published var fullName = ""
  @Published var email = ""
  @Published var password = ""
  @Published var confirmPassword = ""
  @Published var familyCode = ""
  @Published var termsAccepted = false

  // MARK: - UI State

  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var fieldErrors: [String: String] = [:]

  private let authManager: AuthManager
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

  init(authManager: AuthManager = .shared) {
    self.authManager = authManager
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

  func validateFullName() {
    if let error = formValidator.validateName(fullName) {
      fieldErrors["fullName"] = error
    } else {
      fieldErrors["fullName"] = nil
    }
  }

  func validateEmail() {
    if let error = formValidator.validateEmail(email) {
      fieldErrors["email"] = error
    } else {
      fieldErrors["email"] = nil
    }
  }

  func validatePassword() {
    let strengthResult = formValidator.validatePasswordStrength(password)
    if !strengthResult.isValid {
      fieldErrors["password"] = "Password does not meet strength requirements"
    } else {
      fieldErrors["password"] = nil
    }
  }

  func validateConfirmPassword() {
    if let error = formValidator.validatePasswordMatch(password, confirmPassword) {
      fieldErrors["confirmPassword"] = error
    } else {
      fieldErrors["confirmPassword"] = nil
    }
  }

  func validateFamilyCode() {
    guard let role = selectedRole, role.requiresFamilyCode else {
      fieldErrors["familyCode"] = nil
      return
    }

    if let error = formValidator.validateFamilyCode(familyCode) {
      fieldErrors["familyCode"] = error
    } else {
      fieldErrors["familyCode"] = nil
    }
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
      let trimmedFamilyCode = familyCode.trimmingCharacters(in: .whitespaces)
      let familyCodeToUse: String? = if role.requiresFamilyCode {
        trimmedFamilyCode.isEmpty ? nil : familyCode
      } else {
        nil
      }

      try await authManager.signup(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        familyCode: familyCodeToUse
      )
    } catch {
      errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
    }
  }

  func dismissError() {
    errorMessage = nil
  }
}
