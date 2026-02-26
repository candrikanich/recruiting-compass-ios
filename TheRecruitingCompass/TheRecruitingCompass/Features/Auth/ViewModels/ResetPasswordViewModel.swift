import Foundation
import Observation

enum ResetPasswordState: Equatable {
  case form
  case resetting
  case success
  case error(message: String)
}

@Observable
@MainActor
final class ResetPasswordViewModel {
  var state: ResetPasswordState = .form
  var newPassword = ""
  var confirmPassword = ""
  var isPasswordVisible = false
  var fieldErrors: [FormFieldKey: String] = [:]
  var successCountdown = 3
  var shouldNavigateToLogin = false

  private let authManager: any AuthManaging
  private let config: PasswordResetConfig
  @ObservationIgnored private var countdownTask: Task<Void, Never>?

  var passwordStrength: (isValid: Bool, errors: [String]) {
    FormValidator.validatePasswordStrength(newPassword)
  }

  var passwordsMatch: Bool {
    !newPassword.isEmpty && newPassword == confirmPassword
  }

  var isFormValid: Bool {
    passwordStrength.isValid && passwordsMatch && fieldErrors.isEmpty
  }

  var isLoading: Bool {
    state == .resetting
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

  func validateNewPassword() {
    let result = FormValidator.validatePasswordStrength(newPassword)
    if !result.isValid {
      fieldErrors[.newPassword] = "Password does not meet requirements"
    } else {
      fieldErrors[.newPassword] = nil
    }

    if !confirmPassword.isEmpty {
      validateConfirmPassword()
    }
  }

  func validateConfirmPassword() {
    updateFieldValidation(
      FieldValidationInput(
        field: .confirmPassword,
        value: confirmPassword,
        validator: { [weak self] value in
          guard let self = self else { return nil }
          return FormValidator.validatePasswordMatch(self.newPassword, value)
        }
      ),
      &fieldErrors
    )
  }

  func resetPassword() async {
    guard validateAndPrepareForm() else {
      state = .form
      return
    }

    state = .resetting

    do {
      try await executePasswordReset()
      handleResetSuccess()
    } catch {
      handleResetError(error)
    }
  }

  func startSuccessCountdown() {
    successCountdown = config.successCountdownDuration

    countdownTask?.cancel()
    countdownTask = Task { @MainActor in
      for remaining in stride(from: config.successCountdownDuration, through: 0, by: -1) {
        successCountdown = remaining
        if remaining > 0 {
          try? await Task.sleep(nanoseconds: UInt64(config.timerInterval * 1_000_000_000))
        }
      }
      shouldNavigateToLogin = true
    }
  }

  func returnToForm() {
    state = .form
    fieldErrors = [:]
  }

  // MARK: - Private Helpers

  private func validateAndPrepareForm() -> Bool {
    fieldErrors = [:]
    validateNewPassword()
    validateConfirmPassword()
    return isFormValid
  }

  private func executePasswordReset() async throws {
    try await authManager.updatePassword(newPassword: newPassword)
  }

  private func handleResetSuccess() {
    state = .success
    startSuccessCountdown()
  }

  private func handleResetError(_ error: Error) {
    let errorInfo = mapAuthError(error)
    state = .error(message: errorInfo.userMessage)
  }
}
