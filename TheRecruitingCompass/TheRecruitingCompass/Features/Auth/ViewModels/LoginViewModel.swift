import Foundation
import SwiftUI
import Combine

@MainActor
class LoginViewModel: ObservableObject {
  @Published var email = ""
  @Published var password = ""
  @Published var rememberMe = false
  @Published var isLoading = false
  @Published var isValidating = false
  @Published var errorMessage: String?
  @Published var fieldErrors: [String: String] = [:]
  @Published var showTimeoutBanner = false

  private let authManager: any AuthManaging
  private let formValidator = FormValidator.self
  private static let cachedEmailKey = "cachedEmail"

  var isFormValid: Bool {
    !email.trimmingCharacters(in: .whitespaces).isEmpty &&
    !password.isEmpty &&
    fieldErrors.isEmpty
  }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
  }

  init(authManager: any AuthManaging = AuthManager.shared, timeoutReason: String? = nil) {
    self.authManager = authManager
    checkTimeoutReason(timeoutReason)
    loadCachedEmail()
  }

  // MARK: - Timeout Handling

  private func checkTimeoutReason(_ reason: String?) {
    if reason == "timeout" {
      showTimeoutBanner = true
    }
  }

  func dismissTimeoutBanner() {
    showTimeoutBanner = false
  }

  // MARK: - Remember Me & Email Caching

  private func loadCachedEmail() {
    guard let cached = UserDefaults.standard.string(forKey: Self.cachedEmailKey) else {
      return
    }
    email = cached
    rememberMe = true
  }

  private func cacheEmail(_ emailAddress: String) {
    UserDefaults.standard.set(emailAddress, forKey: Self.cachedEmailKey)
  }

  private func clearCachedEmail() {
    UserDefaults.standard.removeObject(forKey: Self.cachedEmailKey)
  }

  // MARK: - Validation

  func validateEmail() {
    isValidating = true
    defer { isValidating = false }

    if let error = formValidator.validateEmail(email) {
      fieldErrors["email"] = error
    } else {
      fieldErrors["email"] = nil
    }
  }

  func validatePassword() {
    isValidating = true
    defer { isValidating = false }

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

    if rememberMe {
      cacheEmail(email)
    } else {
      clearCachedEmail()
    }

    do {
      try await authManager.login(email: email, password: password)
    } catch {
      errorMessage = mapError(error)
    }
  }

  func dismissError() {
    errorMessage = nil
  }

  // MARK: - Error Mapping

  func mapError(_ error: Error) -> String {
    if let authError = error as? AuthError {
      return authError.errorDescription ?? "An error occurred"
    }

    let description = error.localizedDescription
    if description.lowercased().contains("invalid credentials") {
      return "Invalid email or password"
    }
    if description.lowercased().contains("user not found") {
      return "Email not found. Please sign up first."
    }
    if description.lowercased().contains("email not verified") {
      return "Please verify your email. Check your inbox for a verification link."
    }
    if description.lowercased().contains("too many") {
      return "Too many login attempts. Please try again later."
    }
    if description.lowercased().contains("network") {
      return "Network error. Please check your connection and try again."
    }

    return "An error occurred. Please try again."
  }
}
