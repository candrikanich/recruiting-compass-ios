import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class LoginViewModel {
  var email = ""
  var password = ""
  var rememberMe = false
  var isLoading = false
  var isValidating = false
  var errorMessage: String?
  var fieldErrors: [FormFieldKey: String] = [:]
  var showTimeoutBanner = false
  private let biometricService: any BiometricServiceProtocol

  private let authManager: any AuthManaging
  private let formValidator = FormValidator.self
  private let keychain = KeychainHelper.shared
  private static let cachedEmailKey = "cachedEmail"

  var isFormValid: Bool {
    !email.trimmingCharacters(in: .whitespaces).isEmpty &&
    !password.isEmpty &&
    fieldErrors.isEmpty
  }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
  }

  init(
    authManager: (any AuthManaging)? = nil,
    biometricService: (any BiometricServiceProtocol)? = nil,
    timeoutReason: String? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.biometricService = biometricService ?? BiometricService()
    checkTimeoutReason(timeoutReason)
    loadCachedEmail()
  }

  // MARK: - Timeout Handling

  private func checkTimeoutReason(_ reason: String?) {
    showTimeoutBanner = (reason == "timeout")
  }

  func dismissTimeoutBanner() {
    showTimeoutBanner = false
  }

  // MARK: - Remember Me & Email Caching

  private func loadCachedEmail() {
    guard let cached = try? keychain.load(String.self, forKey: Self.cachedEmailKey) else {
      return
    }
    email = cached
    rememberMe = true
  }

  private func cacheEmail(_ emailAddress: String) {
    try? keychain.save(emailAddress, forKey: Self.cachedEmailKey)
  }

  private func clearCachedEmail() {
    try? keychain.delete(forKey: Self.cachedEmailKey)
  }

  // MARK: - Validation

  private func validate(_ field: FormFieldKey, using validator: () -> String?) {
    isValidating = true
    defer { isValidating = false }
    fieldErrors[field] = validator()
  }

  func validateEmail() { validate(.email) { formValidator.validateEmail(email) } }
  func validatePassword() { validate(.password) { formValidator.validatePassword(password) } }

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
      if !authManager.biometricEnabled && biometricService.canEvaluateBiometrics() {
        authManager.pendingBiometricEnrollmentOffer = true
      }
    } catch {
      errorMessage = mapError(error)
    }
  }

  func dismissError() {
    errorMessage = nil
  }

  func errorBinding(for key: FormFieldKey) -> Binding<String?> {
    Binding(
      get: { self.fieldErrors[key] },
      set: { self.fieldErrors[key] = $0 }
    )
  }

  // MARK: - Error Mapping

  private static let errorPatterns: [(pattern: String, message: String)] = [
    ("invalid credentials", "Invalid email or password"),
    ("user not found", "Email not found. Please sign up first."),
    ("email not verified", "Please verify your email. Check your inbox for a verification link."),
    ("too many", "Too many login attempts. Please try again later."),
    ("network", "Network error. Please check your connection and try again.")
  ]

  func mapError(_ error: Error) -> String {
    if let authError = error as? AuthError {
      return authError.errorDescription ?? "An error occurred"
    }
    let description = error.localizedDescription.lowercased()
    return Self.errorPatterns
      .first { description.contains($0.pattern) }
      .map(\.message)
      ?? "An error occurred. Please try again."
  }


}
