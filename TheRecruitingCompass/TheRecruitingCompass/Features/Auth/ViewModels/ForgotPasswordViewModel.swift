import Foundation
import Combine

@MainActor
class ForgotPasswordViewModel: ObservableObject {
  @Published var email = ""
  @Published var isLoading = false
  @Published var emailSent = false
  @Published var submittedEmail = ""
  @Published var errorMessage: String?
  @Published var fieldErrors: [FormFieldKey: String] = [:]
  @Published var canResendEmail = true
  @Published var resendCooldownSeconds = 0

  private let authManager: any AuthManaging
  private var cooldownTimer: AnyCancellable?

  var isFormValid: Bool {
    !email.trimmingCharacters(in: .whitespaces).isEmpty && fieldErrors.isEmpty
  }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
  }

  init(authManager: any AuthManaging = AuthManager.shared) {
    self.authManager = authManager
  }

  func validateEmail() {
    if let error = FormValidator.validateEmail(email) {
      fieldErrors[.email] = error
    } else {
      fieldErrors[.email] = nil
    }
  }

  func sendResetLink() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    validateEmail()
    guard isFormValid else { return }

    do {
      try await authManager.resetPasswordForEmail(email: email)
      submittedEmail = email
      emailSent = true
    } catch {
      errorMessage = mapError(error)
    }
  }

  func resendResetLink() async {
    guard canResendEmail else { return }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await authManager.resetPasswordForEmail(email: submittedEmail)
      startResendCooldown()
    } catch {
      errorMessage = mapError(error)
    }
  }

  func resetForm() {
    emailSent = false
    submittedEmail = ""
    errorMessage = nil
    fieldErrors = [:]
  }

  func dismissError() {
    errorMessage = nil
  }

  private func startResendCooldown() {
    canResendEmail = false
    resendCooldownSeconds = 60

    cooldownTimer = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        guard let self else { return }
        self.resendCooldownSeconds -= 1
        if self.resendCooldownSeconds <= 0 {
          self.canResendEmail = true
          self.cooldownTimer?.cancel()
        }
      }
  }

  private func mapError(_ error: Error) -> String {
    if let authError = error as? AuthError {
      return authError.errorDescription ?? "An error occurred"
    }
    return "An error occurred. Please try again."
  }
}
