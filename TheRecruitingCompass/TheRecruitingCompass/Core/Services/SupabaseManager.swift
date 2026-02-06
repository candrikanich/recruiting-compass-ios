import Foundation
import Supabase
import Helpers

@MainActor
class SupabaseManager {
  static let shared = SupabaseManager()

  private let client: SupabaseClient

  private init() {
    self.client = SupabaseClient(
      supabaseURL: SupabaseConfig.url,
      supabaseKey: SupabaseConfig.anonKey
    )
  }

  // MARK: - Authentication

  func signIn(email: String, password: String) async throws -> (user: User, session: Session) {
    let response = try await client.auth.signIn(
      email: email,
      password: password
    )

    let user = mapToUser(response.user)
    let session = mapToSession(response, user: user)

    return (user, session)
  }

  func signUp(
    email: String,
    password: String,
    fullName: String,
    role: UserRole,
    familyCode: String?
  ) async throws -> (user: User, session: Session?) {
    var metadata: [String: AnyJSON] = [
      "full_name": .string(fullName),
      "role": .string(role.rawValue)
    ]

    if let familyCode = familyCode, !familyCode.trimmingCharacters(in: .whitespaces).isEmpty {
      metadata["family_code"] = .string(familyCode)
    }

    let response = try await client.auth.signUp(
      email: email,
      password: password,
      data: metadata
    )

    let user = mapToUser(response.user)
    let session = response.session.map { mapToSession($0, user: user) }

    return (user, session)
  }

  func signOut() async throws {
    try await client.auth.signOut()
  }

  func getCurrentSession() async throws -> Session? {
    do {
      let authSession = try await client.auth.session
      guard authSession.user.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000") else {
        return nil
      }

      let user = mapToUser(authSession.user)
      return mapToSession(authSession, user: user)
    } catch {
      throw AuthError.unknown(error)
    }
  }

  func refreshSession() async throws -> User {
    do {
      let authSession = try await client.auth.session
      let user = mapToUser(authSession.user)
      return user
    } catch {
      throw AuthError.unknown(error)
    }
  }

  func resendVerificationEmail(email: String) async throws {
    do {
      try await client.auth.resend(
        email: email,
        type: .signup
      )
    } catch {
      throw AuthError.serverError("Failed to resend verification email")
    }
  }

  // MARK: - Private Helpers

  private func mapToUser(_ authUser: Supabase.User) -> User {
    User(
      id: authUser.id.uuidString,
      email: authUser.email ?? "",
      emailConfirmedAt: authUser.emailConfirmedAt?.ISO8601Format(),
      phone: authUser.phone,
      userMetadata: nil,
      createdAt: authUser.createdAt.ISO8601Format(),
      updatedAt: authUser.updatedAt.ISO8601Format()
    )
  }

  private func mapToSession(_ authSession: Supabase.Session, user: User) -> Session {
    Session(
      accessToken: authSession.accessToken,
      tokenType: authSession.tokenType,
      expiresIn: Int(authSession.expiresIn),
      expiresAt: Int(authSession.expiresAt),
      refreshToken: authSession.refreshToken,
      user: user
    )
  }
}
