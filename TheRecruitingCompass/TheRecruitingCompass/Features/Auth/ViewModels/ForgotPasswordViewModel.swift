import Foundation
import Observation

@Observable
@MainActor
class ForgotPasswordViewModel {
  var state: ForgotPasswordState = .form
  var email = ""
  var fieldErrors: [FormFieldKey: String] = [:]
  var resendCooldownSeconds = 0
  var canResendEmail = true

  private let authManager: any AuthManaging
  private let config: PasswordResetConfig
  private var cooldownTask: Task<Void, Never>?

  var submittedEmail: String {
    if case .emailSent(let email) = state {
      return email
    }
    return ""
  }

  var emailSent: Bool {
    if case .emailSent = state {
      return true
    }
    return false
  }

  var errorMessage: String? {
    if case .error(let message) = state {
      return message
    }
    return nil
  }

  var isLoading: Bool {
    state == .sending
  }

  var isFormValid: Bool {
    !email.trimmingCharacters(in: .whitespaces).isEmpty && fieldErrors.isEmpty
  }

  var isButtonDisabled: Bool {
    isLoading || !isFormValid
  }

  init(
    authManager: (any AuthManaging)? = nil,
    config: PasswordResetConfig? = nil
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.config = config ?? .default
  }

  func validateEmail() {
    updateFieldValidation(
      FieldValidationInput(
        field: .email,
        value: email,
        validator: FormValidator.validateEmail(_:)
      ),
      &fieldErrors
    )
  }

  func sendResetLink() async {
    guard validateAndPrepareForm() else { return }

    state = .sending

    do {
      try await executeSendReset(for: email)
      handleSendResetSuccess(for: email)
    } catch {
      handleSendResetError(error)
    }
  }

  func resendResetLink() async {
    guard canResendEmail else { return }

    state = .sending

    do {
      try await executeSendReset(for: submittedEmail)
      startResendCooldown()
    } catch {
      handleSendResetError(error)
    }
  }

  func resetForm() {
    state = .form
    fieldErrors = [:]
  }

  func dismissError() {
    state = .form
  }

  // MARK: - Private Helpers

  private func validateAndPrepareForm() -> Bool {
    validateEmail()
    return isFormValid
  }

  private func executeSendReset(for email: String) async throws {
    try await authManager.resetPasswordForEmail(email: email)
  }

  private func handleSendResetSuccess(for email: String) {
    state = .emailSent(submittedEmail: email)
  }

  private func handleSendResetError(_ error: Error) {
    let errorInfo = mapAuthError(error)
    state = .error(message: errorInfo.userMessage)
  }

  private func startResendCooldown() {
    canResendEmail = false
    resendCooldownSeconds = config.resendCooldownDuration

    cooldownTask?.cancel()
    cooldownTask = Task { @MainActor in
      for remaining in stride(from: config.resendCooldownDuration, through: 0, by: -1) {
        resendCooldownSeconds = remaining
        if remaining > 0 {
          try? await Task.sleep(nanoseconds: UInt64(config.timerInterval * 1_000_000_000))
        }
      }
      canResendEmail = true
    }
  }
}
