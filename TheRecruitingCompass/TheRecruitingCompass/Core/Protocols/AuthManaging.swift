import Foundation

@MainActor
protocol AuthManaging: AnyObject {
  var isAuthenticated: Bool { get }
  var isCheckingSession: Bool { get }
  var user: User? { get }
  var session: Session? { get }
  var biometricEnabled: Bool { get }

  func login(email: String, password: String) async throws
  func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?, dateOfBirth: String?) async throws
  func logout() async throws
  func refreshSession() async throws -> User
  func resendVerificationEmail(email: String) async throws
  func resetPasswordForEmail(email: String) async throws
  func updatePassword(newPassword: String) async throws
  func updateUser(_ user: User)
  func enableBiometrics() throws
  func disableBiometrics()
  func authenticateWithBiometrics() async throws
}
