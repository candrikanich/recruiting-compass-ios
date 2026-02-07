import Foundation
import SwiftUI
import Combine

enum VerificationState: Equatable {
  case pending
  case checking
  case verified
  case error(message: String)

  static func == (lhs: VerificationState, rhs: VerificationState) -> Bool {
    switch (lhs, rhs) {
    case (.pending, .pending), (.checking, .checking), (.verified, .verified):
      return true
    case (.error(let lhsMsg), .error(let rhsMsg)):
      return lhsMsg == rhsMsg
    default:
      return false
    }
  }
}

@MainActor
class EmailVerificationViewModel: ObservableObject {
  // MARK: - Published State

  @Published var verificationState: VerificationState = .pending
  @Published var errorMessage: String?
  @Published var resendCooldownSeconds: Int = 0
  @Published var canResendEmail: Bool = true

  // MARK: - Private State

  private var pollingTask: Task<Void, Never>?
  private var cooldownTask: Task<Void, Never>?
  private var currentInterval: TimeInterval
  private let initialInterval: TimeInterval
  private let maxInterval: TimeInterval
  private let maxConsecutiveErrors: Int
  private var consecutiveErrors: Int = 0

  private let authManager: any AuthManaging

  // MARK: - Computed Properties

  var userEmail: String? { authManager.user?.email }
  var isVerified: Bool { authManager.user?.emailConfirmedAt != nil }

  // MARK: - Initialization

  init(
    authManager: (any AuthManaging)? = nil,
    initialPollingInterval: TimeInterval = 2.0,
    maxPollingInterval: TimeInterval = 10.0,
    maxConsecutiveErrors: Int = 3
  ) {
    self.authManager = authManager ?? AuthManager.shared
    self.initialInterval = initialPollingInterval
    self.currentInterval = initialPollingInterval
    self.maxInterval = maxPollingInterval
    self.maxConsecutiveErrors = maxConsecutiveErrors

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
        try? await Task.sleep(nanoseconds: UInt64(currentInterval * 1_000_000_000))
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
    resendCooldownSeconds = 60
    cooldownTask?.cancel()

    cooldownTask = Task {
      while resendCooldownSeconds > 0 && !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
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
