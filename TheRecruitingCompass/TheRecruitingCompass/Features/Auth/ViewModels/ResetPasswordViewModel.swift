import Foundation
import Combine

enum ResetPasswordState: Equatable {
  case form
  case resetting
  case success
  case error(message: String)
}

@MainActor
class ResetPasswordViewModel: ObservableObject {
  @Published var state: ResetPasswordState = .form
  @Published var newPassword = ""
  @Published var confirmPassword = ""
  @Published var isPasswordVisible = false
  @Published var fieldErrors: [String: String] = [:]
  @Published var successCountdown = 3
  @Published var shouldNavigateToLogin = false

  private let authManager: any AuthManaging
  private var countdownTimer: AnyCancellable?

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

  init(authManager: any AuthManaging = AuthManager.shared) {
    self.authManager = authManager
  }

  func validateNewPassword() {
    let result = FormValidator.validatePasswordStrength(newPassword)
    if !result.isValid {
      fieldErrors["newPassword"] = "Password does not meet requirements"
    } else {
      fieldErrors["newPassword"] = nil
    }

    if !confirmPassword.isEmpty {
      validateConfirmPassword()
    }
  }

  func validateConfirmPassword() {
    if let error = FormValidator.validatePasswordMatch(newPassword, confirmPassword) {
      fieldErrors["confirmPassword"] = error
    } else {
      fieldErrors["confirmPassword"] = nil
    }
  }

  func resetPassword() async {
    state = .resetting
    fieldErrors = [:]

    validateNewPassword()
    validateConfirmPassword()

    guard isFormValid else {
      state = .form
      return
    }

    do {
      try await authManager.updatePassword(newPassword: newPassword)
      state = .success
      startSuccessCountdown()
    } catch {
      let message = (error as? AuthError)?.errorDescription ?? "Failed to reset password. Please try again."
      state = .error(message: message)
    }
  }

  func startSuccessCountdown() {
    successCountdown = 3

    countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        guard let self else { return }
        self.successCountdown -= 1
        if self.successCountdown <= 0 {
          self.shouldNavigateToLogin = true
          self.countdownTimer?.cancel()
        }
      }
  }

  func returnToForm() {
    state = .form
    fieldErrors = [:]
  }
}
