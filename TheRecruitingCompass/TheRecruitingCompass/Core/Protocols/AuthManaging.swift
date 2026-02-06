import Foundation

@MainActor
protocol AuthManaging: AnyObject {
  var isAuthenticated: Bool { get }
  var user: User? { get }
  var session: Session? { get }

  func login(email: String, password: String) async throws
  func signup(email: String, password: String, fullName: String, role: UserRole, familyCode: String?) async throws
  func logout() async throws
  func refreshSession() async throws -> User
  func resendVerificationEmail(email: String) async throws
}
