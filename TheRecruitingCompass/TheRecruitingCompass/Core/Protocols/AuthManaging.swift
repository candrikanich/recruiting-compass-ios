import Foundation

@MainActor
protocol AuthManaging: AnyObject {
  var isAuthenticated: Bool { get }
  var user: User? { get }
  var session: Session? { get }

  func refreshSession() async throws -> User
  func resendVerificationEmail(email: String) async throws
}
