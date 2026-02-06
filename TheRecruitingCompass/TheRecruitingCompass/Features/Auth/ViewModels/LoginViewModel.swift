import Foundation
import SwiftUI
import Combine

@MainActor
class LoginViewModel: ObservableObject {
  @Published var email = ""
  @Published var password = ""
  @Published var rememberMe = false
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var fieldErrors: [String: String] = [:]
  @Published var showTimeoutBanner = false

  private let authManager: AuthManager
  private let formValidator = FormValidator.self

  var isFormValid: Bool {
    !email.trimmingCharacters(in: .whitespaces).isEmpty &&
    !password.isEmpty &&
    fieldErrors.isEmpty
  }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
  }

  init(authManager: AuthManager = .shared) {
    self.authManager = authManager
  }

  // MARK: - Validation

  func validateEmail() {
    if let error = formValidator.validateEmail(email) {
      fieldErrors["email"] = error
    } else {
      fieldErrors["email"] = nil
    }
  }

  func validatePassword() {
    if let error = formValidator.validatePassword(password) {
      fieldErrors["password"] = error
    } else {
      fieldErrors["password"] = nil
    }
  }

  // MARK: - Actions

  func login() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    validateEmail()
    validatePassword()

    guard isFormValid else {
      errorMessage = "Please fix the errors above"
      return
    }

    do {
      try await authManager.login(email: email, password: password)
    } catch {
      errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
    }
  }

  func dismissError() {
    errorMessage = nil
  }

  func dismissTimeoutBanner() {
    showTimeoutBanner = false
  }
}
