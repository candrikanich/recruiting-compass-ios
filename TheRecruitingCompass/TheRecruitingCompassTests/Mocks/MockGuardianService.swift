import Foundation
@testable import TheRecruitingCompass

final class MockGuardianService: GuardianManaging, @unchecked Sendable {
  var signupMinorCallCount = 0
  var fetchStatusCallCount = 0
  var resendCallCount = 0
  var resolveClaimCallCount = 0
  var acceptClaimCallCount = 0

  var shouldThrowSignupMinorError = false
  var shouldThrowFetchStatusError = false
  var shouldThrowResendError = false
  var shouldThrowResolveClaimError = false
  var shouldThrowAcceptClaimError = false

  var mockErrorToThrow: Error = GuardianServiceError.server(500, message: "Mock error")

  var mockSignupMinorResult = SignupMinorResult(ok: true, guardianEmail: "guardian@example.com", guardianEmailSent: true)
  var mockStatus = GuardianStatus(pending: false, guardianEmailMasked: nil, expiresAt: nil, status: nil)
  var mockClaimDetails = GuardianClaimDetails(
    guardianEmail: "guardian@example.com", playerName: "Test Player",
    playerDateOfBirth: nil, playerGraduationYear: nil, expiresAt: "2026-12-31T00:00:00Z")
  var mockAcceptResult = GuardianClaimAcceptResult(success: true, familyUnitId: "family-1")

  private(set) var capturedSignupMinorEmail: String?
  private(set) var capturedSignupMinorGuardianEmail: String?
  private(set) var capturedResolveClaimToken: String?
  private(set) var capturedAcceptClaimToken: String?

  func signupMinor(
    email: String, password: String, firstName: String, lastName: String,
    dateOfBirth: String, guardianEmail: String, captchaToken: String?
  ) async throws -> SignupMinorResult {
    signupMinorCallCount += 1
    capturedSignupMinorEmail = email
    capturedSignupMinorGuardianEmail = guardianEmail
    if shouldThrowSignupMinorError { throw mockErrorToThrow }
    return mockSignupMinorResult
  }

  func fetchStatus(accessToken: String) async throws -> GuardianStatus {
    fetchStatusCallCount += 1
    if shouldThrowFetchStatusError { throw mockErrorToThrow }
    return mockStatus
  }

  func resend(accessToken: String, guardianEmail: String?) async throws {
    resendCallCount += 1
    if shouldThrowResendError { throw mockErrorToThrow }
  }

  func resolveClaim(token: String) async throws -> GuardianClaimDetails {
    resolveClaimCallCount += 1
    capturedResolveClaimToken = token
    if shouldThrowResolveClaimError { throw mockErrorToThrow }
    return mockClaimDetails
  }

  func acceptClaim(token: String, accessToken: String) async throws -> GuardianClaimAcceptResult {
    acceptClaimCallCount += 1
    capturedAcceptClaimToken = token
    if shouldThrowAcceptClaimError { throw mockErrorToThrow }
    return mockAcceptResult
  }
}
