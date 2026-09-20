import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "EmailVerificationBannerViewModel"
)

/// Drives the dashboard's email-verification banner. Mirrors
/// `GuardianStatusViewModel` — fails open on any network error, never blocks
/// the dashboard on a status-check or resend failure.
@Observable
@MainActor
final class EmailVerificationBannerViewModel {
  nonisolated deinit {}

  var isResending = false
  var resendMessage: String?
  var resendFailed = false

  private let emailVerificationService: any EmailVerificationManaging
  private let authManager: any AuthManaging

  var isVerified: Bool { authManager.user?.emailConfirmedAt != nil }

  init(
    emailVerificationService: (any EmailVerificationManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.emailVerificationService = emailVerificationService ?? EmailVerificationServiceImpl()
    self.authManager = authManager ?? AuthManager.shared
  }

  /// Re-fetches the user profile so a verification completed since last
  /// launch (e.g. the user tapped the emailed link) is picked up. Mirrors
  /// web's `onMounted() => userStore.refreshVerificationStatus()`.
  func refresh() async {
    do {
      _ = try await authManager.refreshSession()
    } catch {
      logger.error("Failed to refresh session for verification status: \(error.localizedDescription)")
    }
  }

  func resend() async {
    guard let token = authManager.session?.accessToken else { return }
    isResending = true
    defer { isResending = false }
    do {
      try await emailVerificationService.resend(accessToken: token)
      resendMessage = "Sent!"
      resendFailed = false
    } catch {
      resendMessage = (error as? EmailVerificationServiceError)?.errorDescription ?? "Could not resend. Please try again."
      resendFailed = true
    }
  }
}
