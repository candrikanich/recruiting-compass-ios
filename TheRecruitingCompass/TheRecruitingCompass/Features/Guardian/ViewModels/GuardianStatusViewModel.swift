import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "GuardianStatusViewModel"
)

/// Drives the dashboard's guardian-pending banner. Fails open on any network
/// error — a status-check failure must never fabricate a lock.
@Observable
@MainActor
final class GuardianStatusViewModel {
  nonisolated deinit {}

  var status: GuardianStatus?
  var isLoading = false
  var isResending = false
  var resendMessage: String?

  private let guardianService: any GuardianManaging
  private let authManager: any AuthManaging

  var isPending: Bool { status?.pending == true }

  init(
    guardianService: (any GuardianManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.guardianService = guardianService ?? GuardianServiceImpl()
    self.authManager = authManager ?? AuthManager.shared
  }

  func refresh() async {
    guard let token = authManager.session?.accessToken else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      status = try await guardianService.fetchStatus(accessToken: token)
    } catch {
      logger.error("Failed to fetch guardian status: \(error.localizedDescription)")
    }
  }

  func resend() async {
    guard let token = authManager.session?.accessToken else { return }
    isResending = true
    defer { isResending = false }
    do {
      try await guardianService.resend(accessToken: token, guardianEmail: nil)
      resendMessage = "Confirmation email resent."
    } catch {
      resendMessage = (error as? GuardianServiceError)?.errorDescription ?? "Could not resend. Please try again."
    }
  }
}
