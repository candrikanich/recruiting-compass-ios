import Foundation
@testable import TheRecruitingCompass

/// Test double for the web-API guardian endpoints.
///
/// `isConfigured` defaults to true so tests exercise the real minor-signup path; the
/// unconfigured case (no `API_BASE_URL`) is its own scenario rather than the default,
/// since that build can't offer the flow at all.
final class MockGuardianClaimService: GuardianClaimServicing, @unchecked Sendable {
  var isConfigured: Bool = true

  private(set) var signupMinorCallCount = 0
  private(set) var capturedSignupInput: MinorSignupInput?
  private(set) var resendCallCount = 0
  private(set) var capturedResendEmail: String?

  var signupMinorError: Error?
  var statusToReturn = GuardianStatus(
    pending: false,
    guardianEmailMasked: nil,
    expiresAt: nil,
    status: nil
  )
  var statusError: Error?
  var resendError: Error?

  func signupMinor(_ input: MinorSignupInput) async throws {
    signupMinorCallCount += 1
    capturedSignupInput = input
    if let signupMinorError { throw signupMinorError }
  }

  func status(accessToken: String?) async throws -> GuardianStatus {
    if let statusError { throw statusError }
    return statusToReturn
  }

  func resend(guardianEmail: String?, accessToken: String?) async throws {
    resendCallCount += 1
    capturedResendEmail = guardianEmail
    if let resendError { throw resendError }
  }
}
