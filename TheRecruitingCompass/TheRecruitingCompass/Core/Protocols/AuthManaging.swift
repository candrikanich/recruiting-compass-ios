import Foundation

/// Contract for authentication state management and operations.
///
/// Conform to this protocol to enable dependency injection and mock-based testing.
/// The concrete implementation is `AuthManager` (a singleton). Views and ViewModels
/// depend on `AuthManaging` rather than `AuthManager` directly.
@MainActor
protocol AuthManaging: AnyObject {
  /// Whether a valid, unexpired session is currently active.
  var isAuthenticated: Bool { get }
  /// `true` while the initial session-restore check is in progress on app launch.
  var isCheckingSession: Bool { get }
  /// The currently authenticated user, or `nil` when signed out.
  var user: User? { get }
  /// The live Supabase session (access + refresh tokens), or `nil` when signed out.
  var session: Session? { get }
  /// Whether Face ID / Touch ID unlock is currently enabled for this device.
  var biometricEnabled: Bool { get }
  /// Set to `true` to show the biometric enrollment prompt after a successful login.
  var pendingBiometricEnrollmentOffer: Bool { get set }

  /// Signs in with email and password. Persists the resulting session to Keychain.
  func login(email: String, password: String) async throws
  /// Creates a new account and signs in. Passes `familyCode` to join an existing family unit.
  /// - Parameter dateOfBirth: ISO 8601 date string used for COPPA age-gate enforcement.
  func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?, dateOfBirth: String?) async throws
  /// Signs out, revokes the Supabase session, and clears Keychain tokens.
  func logout() async throws
  /// Refreshes the access token using the stored refresh token and returns the updated user.
  func refreshSession() async throws -> User
  /// Re-sends the email verification link to the given address.
  func resendVerificationEmail(email: String) async throws
  /// Triggers a Supabase password-reset email to the given address.
  func resetPasswordForEmail(email: String) async throws
  /// Updates the password for the currently authenticated user.
  func updatePassword(newPassword: String) async throws
  /// Replaces the locally cached user object without a network call.
  func updateUser(_ user: User)
  /// Enables biometric unlock by storing a flag in Keychain. Throws `BiometricError` if not available.
  func enableBiometrics() throws
  /// Removes the biometric-enabled flag from Keychain.
  func disableBiometrics()
  /// Presents the Face ID / Touch ID prompt and throws `BiometricError` on failure or cancellation.
  func authenticateWithBiometrics() async throws
}
