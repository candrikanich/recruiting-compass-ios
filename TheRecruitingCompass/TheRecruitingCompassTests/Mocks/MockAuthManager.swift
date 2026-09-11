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

  private(set) var capturedLoginCaptchaToken: String?
  private(set) var capturedSignupCaptchaToken: String?
  private(set) var capturedResetEmailCaptchaToken: String?
  private(set) var capturedResendEmailCaptchaToken: String?
  private(set) var capturedSignupGraduationYear: Int?
  private(set) var capturedSignupPrimarySport: String?
  private(set) var capturedSignupGender: String?
  private(set) var capturedSignupZipCode: String?

  /// When false, signup() does not set isAuthenticated = true, so SignupViewModel sets shouldNavigateToVerifyEmail (e.g. email confirmation required).
  var setAuthenticatedAfterSignup = true

  // MARK: - Biometric Mock State
  var biometricEnabled: Bool = false
  var pendingBiometricEnrollmentOffer: Bool = false
  var enableBiometricsCallCount = 0
  var disableBiometricsCallCount = 0
  var authenticateWithBiometricsCallCount = 0
  var shouldThrowEnableBiometricsError = false
  var shouldThrowBiometricAuthError = false
  var mockBiometricError: Error = BiometricError.failed

  func enableBiometrics() throws {
    enableBiometricsCallCount += 1
    if shouldThrowEnableBiometricsError { throw mockBiometricError }
    biometricEnabled = true
  }

  func disableBiometrics() {
    disableBiometricsCallCount += 1
    biometricEnabled = false
  }

  func authenticateWithBiometrics() async throws {
    authenticateWithBiometricsCallCount += 1
    if shouldThrowBiometricAuthError { throw mockBiometricError }
  }

  // MARK: - AuthManaging Methods

  func login(email: String, password: String, captchaToken: String) async throws {
    loginCallCount += 1
    capturedLoginCaptchaToken = captchaToken

    if shouldThrowLoginError {
      throw mockErrorToThrow
    }

    let user = mockUserToReturn ?? User(
      id: "test-user-id",
      email: email,
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      fullName: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil,
      dateOfBirth: nil
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
    familyCode: String?,
    dateOfBirth: String? = nil,
    graduationYear: Int? = nil,
    primarySport: String? = nil,
    gender: String? = nil,
    zipCode: String? = nil,
    captchaToken: String
  ) async throws {
    signupCallCount += 1
    capturedSignupCaptchaToken = captchaToken
    capturedSignupGraduationYear = graduationYear
    capturedSignupPrimarySport = primarySport
    capturedSignupGender = gender
    capturedSignupZipCode = zipCode

    if shouldThrowSignupError {
      throw mockErrorToThrow
    }

    let user = mockUserToReturn ?? User(
      id: "test-user-id",
      email: email,
      emailConfirmedAt: nil,
      phone: nil,
      fullName: fullName,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role,
      dateOfBirth: nil
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
    if setAuthenticatedAfterSignup {
      self.isAuthenticated = true
    }
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

  func resendVerificationEmail(email: String, captchaToken: String) async throws {
    resendEmailCallCount += 1
    capturedResendEmailCaptchaToken = captchaToken

    if shouldThrowResendError {
      throw mockErrorToThrow
    }
  }

  func resetPasswordForEmail(email: String, captchaToken: String) async throws {
    resetEmailCallCount += 1
    capturedResetEmailCaptchaToken = captchaToken
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

  func updateUser(_ user: User) {
    self.user = user
    self.mockUserToReturn = user
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

    capturedLoginCaptchaToken = nil
    capturedSignupCaptchaToken = nil
    capturedResetEmailCaptchaToken = nil
    capturedResendEmailCaptchaToken = nil
    capturedSignupGraduationYear = nil
    capturedSignupPrimarySport = nil
    capturedSignupGender = nil
    capturedSignupZipCode = nil

    user = nil
    mockUserToReturn = nil
    session = nil
    mockSessionToReturn = nil
    isAuthenticated = false
    errorMessage = nil
    biometricEnabled = false
    pendingBiometricEnrollmentOffer = false
    enableBiometricsCallCount = 0
    disableBiometricsCallCount = 0
    authenticateWithBiometricsCallCount = 0
    shouldThrowEnableBiometricsError = false
    shouldThrowBiometricAuthError = false
  }
}
