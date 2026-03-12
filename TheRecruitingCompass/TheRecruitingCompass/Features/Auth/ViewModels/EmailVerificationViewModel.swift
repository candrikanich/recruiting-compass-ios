import Foundation
import Observation
import SwiftUI

enum VerificationState: Equatable {
  case pending
  case checking
  case verified
  case error(message: String)
}

@Observable
@MainActor
final class EmailVerificationViewModel {
  // MARK: - State

  var verificationState: VerificationState = .pending
  var errorMessage: String?
  var resendCooldownSeconds: Int = 0
  var canResendEmail: Bool = true

  // MARK: - Private State

  @ObservationIgnored nonisolated(unsafe) private var pollingTask: Task<Void, Never>?
  @ObservationIgnored nonisolated(unsafe) private var cooldownTask: Task<Void, Never>?
  private(set) var currentInterval: TimeInterval
  private let initialInterval: TimeInterval
  private let maxInterval: TimeInterval
  private let maxConsecutiveErrors: Int
  private(set) var consecutiveErrors: Int = 0
  private let cooldownDuration: Int

  private let authManager: any AuthManaging

  // MARK: - Computed Properties

  var userEmail: String? { authManager.user?.email }
  var isVerified: Bool { authManager.user?.emailConfirmedAt != nil }
  var isPolling: Bool { pollingTask != nil }

  var headlineText: String {
    switch verificationState {
    case .pending, .checking:
      return "Verify Your Email"
    case .verified:
      return "Verified!"
    case .error:
      return "Verification Issue"
    }
  }

  var subtitleText: String {
    switch verificationState {
    case .pending:
      return "We've sent a verification link to your email. Click it to verify your account."
    case .checking:
      return "Checking your email verification status..."
    case .verified:
      return "Your email has been verified successfully! You can now access the app."
    case .error:
      return "We encountered an issue verifying your email. Please try again."
    }
  }

  var actionButtonText: String {
    if isVerified {
      return "Continue to Dashboard"
    } else if !canResendEmail {
      return "Resend Email (Cooldown)"
    } else {
      return "Resend Verification Email"
    }
  }

  var isButtonDisabled: Bool {
    if isVerified { return false }
    return !canResendEmail || verificationState == .checking
  }

  var accessibilityLabelForButton: String {
    if isVerified {
      return "Continue to dashboard"
    } else if verificationState == .checking {
      return "Checking verification status"
    } else {
      return "Resend verification email"
    }
  }

  var accessibilityHintForButton: String {
    if isVerified {
      return "Navigate to dashboard"
    } else if !canResendEmail {
      return "Wait \(resendCooldownSeconds) seconds before resending"
    } else {
      return "Send another verification email"
    }
  }

  var shouldShowCooldownText: Bool {
    !canResendEmail && !isVerified
  }

  // MARK: - Initialization

  init(
    authManager: (any AuthManaging)? = nil,
    initialPollingInterval: TimeInterval = 2.0,
    maxPollingInterval: TimeInterval = 10.0,
    maxConsecutiveErrors: Int = 3,
    cooldownDuration: Int = 60
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.initialInterval = initialPollingInterval
    self.currentInterval = initialPollingInterval
    self.maxInterval = maxPollingInterval
    self.maxConsecutiveErrors = maxConsecutiveErrors
    self.cooldownDuration = cooldownDuration

    // Check initial verification state
    if isVerified {
      verificationState = .verified
    }
  }

  // MARK: - Public Methods

  func startPolling() {
    guard !isVerified else { return }
    guard pollingTask == nil else { return }

    pollingTask = Task {
      while !Task.isCancelled && !isVerified {
        verificationState = .checking

        await checkVerificationStatus()

        guard !isVerified else { break }
        try? await Task.sleep(for: .seconds(currentInterval))
      }

      if isVerified {
        verificationState = .verified
      }
    }
  }

  func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
  }

  func resendVerificationEmail() async {
    guard canResendEmail else { return }
    guard let email = userEmail else { return }

    do {
      try await authManager.resendVerificationEmail(email: email)
      errorMessage = nil
      startResendCooldown()
    } catch {
      errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
    }
  }

  func onAppear() {
    if !isVerified {
      startPolling()
    }
  }

  func onDisappear() {
    stopPolling()
  }

  func dismissError() {
    errorMessage = nil
  }

  // MARK: - Private Methods

  private func checkVerificationStatus() async {
    do {
      let updatedUser = try await authManager.refreshSession()

      if updatedUser.emailConfirmedAt != nil {
        verificationState = .verified
      } else {
        verificationState = .pending
      }

      resetBackoff()
    } catch {
      handlePollingError(error)
    }
  }

  private func handlePollingError(_ error: Error) {
    consecutiveErrors += 1

    if consecutiveErrors <= maxConsecutiveErrors {
      applyExponentialBackoff()
      verificationState = .pending
    } else {
      verificationState = .error(message: "Unable to verify email. Please check your connection.")
      errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
      stopPolling()
    }
  }

  private func applyExponentialBackoff() {
    currentInterval = min(currentInterval * 2, maxInterval)
  }

  private func resetBackoff() {
    currentInterval = initialInterval
    consecutiveErrors = 0
  }

  private func startResendCooldown() {
    canResendEmail = false
    resendCooldownSeconds = cooldownDuration
    cooldownTask?.cancel()

    cooldownTask = Task {
      while resendCooldownSeconds > 0 && !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        resendCooldownSeconds -= 1
      }

      if resendCooldownSeconds == 0 && !Task.isCancelled {
        canResendEmail = true
      }
    }
  }

  deinit {
    // Cancel tasks (don't call stopPolling here to avoid MainActor crossing)
    pollingTask?.cancel()
    cooldownTask?.cancel()
  }
}
