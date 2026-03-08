import Foundation
@testable import TheRecruitingCompass

final class MockSupabaseManager: SupabaseManaging {
  var setSessionError: Error?
  var signInResult: Result<(user: User, session: Session), Error> = .failure(AuthError.networkError("Mock: not configured"))
  var signUpResult: Result<(user: User, session: Session?), Error> = .failure(AuthError.networkError("Mock: not configured"))
  var signOutError: Error?
  var currentSessionResult: Session? = nil
  var refreshSessionResult: Result<User, Error> = .failure(AuthError.networkError("Mock: not configured"))
  var resendVerificationEmailError: Error?
  var resetPasswordError: Error?
  var updatePasswordError: Error?

  func setSession(accessToken: String, refreshToken: String) async throws {
    if let error = setSessionError { throw error }
  }

  func signIn(email: String, password: String) async throws -> (user: User, session: Session) {
    try signInResult.get()
  }

  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?
  ) async throws -> (user: User, session: Session?) {
    try signUpResult.get()
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

  func resetPasswordForEmail(email: String) async throws {
    if let error = resetPasswordError { throw error }
  }

  func updatePassword(newPassword: String) async throws {
    if let error = updatePasswordError { throw error }
  }
}
