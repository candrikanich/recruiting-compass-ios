import Foundation

/// Protocol for Supabase auth operations. Enables dependency injection and testing (e.g. MockSupabaseManager).
protocol SupabaseManaging: Sendable {
  func signIn(email: String, password: String) async throws -> (user: User, session: Session)
  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?
  ) async throws -> (user: User, session: Session?)
  func signOut() async throws
  func getCurrentSession() async throws -> Session?
  func refreshSession() async throws -> User
  func resendVerificationEmail(email: String) async throws
  func resetPasswordForEmail(email: String) async throws
  func updatePassword(newPassword: String) async throws
}
