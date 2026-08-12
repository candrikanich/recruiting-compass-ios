import Foundation

/// Protocol for Supabase auth operations. Enables dependency injection and testing (e.g. MockSupabaseManager).
protocol SupabaseManaging: Sendable {
  /// Restores the Supabase client session from stored tokens. Call before refreshSession when restoring from Keychain.
  func setSession(accessToken: String, refreshToken: String) async throws
  /// Authenticates with email and password and returns the resolved user and session.
  func signIn(email: String, password: String) async throws -> (user: User, session: Session)
  /// Creates a new Supabase user. The session may be `nil` if email confirmation is required before sign-in.
  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?
  ) async throws -> (user: User, session: Session?)
  /// Invalidates the current session on the Supabase backend.
  func signOut() async throws
  /// Returns the active session if one exists and the token has not expired, otherwise `nil`.
  func getCurrentSession() async throws -> Session?
  /// Uses the stored refresh token to obtain a new access token and returns the updated user.
  func refreshSession() async throws -> User
  /// Sends a new verification email to the given address.
  func resendVerificationEmail(email: String) async throws
  /// Sends a password-reset email to the given address.
  func resetPasswordForEmail(email: String) async throws
  /// Updates the password for the currently authenticated Supabase user.
  func updatePassword(newPassword: String) async throws
}
