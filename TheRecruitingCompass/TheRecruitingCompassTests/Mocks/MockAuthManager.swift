import Foundation
@testable import TheRecruitingCompass

@MainActor
class MockAuthManager: AuthManaging {
  // MARK: - Published Properties

  var isAuthenticated: Bool = false
  var user: User?
  var session: Session?

  // MARK: - Mock State

  var refreshSessionCallCount = 0
  var resendEmailCallCount = 0
  var shouldThrowRefreshError = false
  var shouldThrowResendError = false
  var mockUserToReturn: User?
  var mockErrorToThrow: AuthError = .networkError("Mock network error")

  // MARK: - AuthManaging Methods

  func refreshSession() async throws -> User {
    refreshSessionCallCount += 1

    if shouldThrowRefreshError {
      throw mockErrorToThrow
    }

    if let mockUser = mockUserToReturn {
      self.user = mockUser
      return mockUser
    }

    throw AuthError.userNotFound
  }

  func resendVerificationEmail(email: String) async throws {
    resendEmailCallCount += 1

    if shouldThrowResendError {
      throw mockErrorToThrow
    }
  }

  // MARK: - Helper Methods

  func setMockUser(_ user: User) {
    self.user = user
    self.mockUserToReturn = user
    self.isAuthenticated = true
  }

  func reset() {
    refreshSessionCallCount = 0
    resendEmailCallCount = 0
    shouldThrowRefreshError = false
    shouldThrowResendError = false
    user = nil
    mockUserToReturn = nil
    isAuthenticated = false
  }
}
