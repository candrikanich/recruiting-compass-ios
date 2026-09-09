import Foundation
@testable import TheRecruitingCompass

final class MockSupabaseManager: SupabaseManaging {
  var setSessionError: Error?
  var signInResult: Result<(user: User, session: Session), Error> = .failure(AuthError.networkError("Mock: not configured"))
  var signUpResult: Result<(user: User, session: Session?), Error> = .failure(AuthError.networkError("Mock: not configured"))
  var signOutError: Error?
  var currentSessionResult: Session?
  var refreshSessionResult: Result<User, Error> = .failure(AuthError.networkError("Mock: not configured"))
  var resendVerificationEmailError: Error?
  var resetPasswordError: Error?
  var updatePasswordError: Error?

  func setSession(accessToken: String, refreshToken: String) async throws {
    if let error = setSessionError { throw error }
  }

  private(set) var capturedSignInCaptchaToken: String?
  private(set) var capturedSignUpCaptchaToken: String?
  private(set) var capturedResetPasswordCaptchaToken: String?

  func signIn(email: String, password: String, captchaToken: String) async throws -> (user: User, session: Session) {
    capturedSignInCaptchaToken = captchaToken
    return try signInResult.get()
  }

  private(set) var capturedSignUpDateOfBirth: String?

  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?,
    dateOfBirth: String?,
    captchaToken: String
  ) async throws -> (user: User, session: Session?) {
    capturedSignUpDateOfBirth = dateOfBirth
    capturedSignUpCaptchaToken = captchaToken
    return try signUpResult.get()
  }

  func signOut() async throws {
    if let error = signOutError { throw error }
  }

  func getCurrentSession() async throws -> Session? {
    currentSessionResult
  }

  func refreshSession() async throws -> User {
    try refreshSessionResult.get()
  }

  func resendVerificationEmail(email: String) async throws {
    if let error = resendVerificationEmailError { throw error }
  }

  func resetPasswordForEmail(email: String, captchaToken: String) async throws {
    capturedResetPasswordCaptchaToken = captchaToken
    if let error = resetPasswordError { throw error }
  }

  func updatePassword(newPassword: String) async throws {
    if let error = updatePasswordError { throw error }
  }
}
