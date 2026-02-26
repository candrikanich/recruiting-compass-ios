import Foundation
import Observation
@testable import TheRecruitingCompass

@Observable
@MainActor
class MockAuthManager: AuthManaging {
  // MARK: - Observable State

  var isAuthenticated: Bool = false
  var isCheckingSession: Bool = false
  var user: User?
  var session: Session?
  var errorMessage: String?

  // MARK: - Mock State

  var refreshSessionCallCount = 0
  var resendEmailCallCount = 0
  var loginCallCount = 0
  var signupCallCount = 0

  var shouldThrowRefreshError = false
  var shouldThrowResendError = false
  var shouldThrowLoginError = false
  var shouldThrowSignupError = false
  var shouldThrowResetEmailError = false
  var shouldThrowUpdatePasswordError = false
  var shouldThrowLogoutError = false

  var resetEmailCallCount = 0
  var updatePasswordCallCount = 0
  var logoutCallCount = 0

  var mockUserToReturn: User?
  var mockSessionToReturn: Session?
  var mockErrorToThrow: AuthError = .networkError("Mock network error")

  // MARK: - AuthManaging Methods

  func login(email: String, password: String) async throws {
    loginCallCount += 1

    if shouldThrowLoginError {
      throw mockErrorToThrow
    }

    let user = mockUserToReturn ?? User(
      id: "test-user-id",
      email: email,
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil
    )

    let session = mockSessionToReturn ?? Session(
      accessToken: "test-access-token",
      tokenType: "bearer",
      expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600,
      refreshToken: "test-refresh-token",
      user: user
    )

    self.user = user
    self.session = session
    self.isAuthenticated = true
    self.errorMessage = nil
  }

  func signup(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?
  ) async throws {
    signupCallCount += 1

    if shouldThrowSignupError {
      throw mockErrorToThrow
    }

    let user = mockUserToReturn ?? User(
      id: "test-user-id",
      email: email,
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role
    )

    let session = mockSessionToReturn ?? Session(
      accessToken: "test-access-token",
      tokenType: "bearer",
      expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600,
      refreshToken: "test-refresh-token",
      user: user
    )

    self.user = user
    self.session = session
    self.isAuthenticated = true
    self.errorMessage = nil
  }

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

  func resetPasswordForEmail(email: String) async throws {
    resetEmailCallCount += 1
    if shouldThrowResetEmailError {
      throw mockErrorToThrow
    }
  }

  func updatePassword(newPassword: String) async throws {
    updatePasswordCallCount += 1
    if shouldThrowUpdatePasswordError {
      throw mockErrorToThrow
    }
  }

  func logout() async throws {
    logoutCallCount += 1

    if shouldThrowLogoutError {
      throw mockErrorToThrow
    }

    self.user = nil
    self.session = nil
    self.isAuthenticated = false
    self.errorMessage = nil
  }

  // MARK: - Helper Methods

  func setMockUser(_ user: User) {
    self.user = user
    self.mockUserToReturn = user
    self.isAuthenticated = true
  }

  func setMockSession(_ session: Session) {
    self.session = session
    self.mockSessionToReturn = session
  }

  func reset() {
    refreshSessionCallCount = 0
    resendEmailCallCount = 0
    loginCallCount = 0
    signupCallCount = 0

    shouldThrowRefreshError = false
    shouldThrowResendError = false
    shouldThrowLoginError = false
    shouldThrowSignupError = false
    shouldThrowResetEmailError = false
    shouldThrowUpdatePasswordError = false
    shouldThrowLogoutError = false
    resetEmailCallCount = 0
    updatePasswordCallCount = 0
    logoutCallCount = 0

    user = nil
    mockUserToReturn = nil
    session = nil
    mockSessionToReturn = nil
    isAuthenticated = false
    errorMessage = nil
  }
}
