import Foundation
import Supabase
import Helpers
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "UserProfile"
)

// Support for nested JSON objects in metadata
struct AnyCodable: Codable {
  let value: Any

  init(value: Any) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let intVal = try? container.decode(Int.self) {
      value = intVal
    } else if let doubleVal = try? container.decode(Double.self) {
      value = doubleVal
    } else if let boolVal = try? container.decode(Bool.self) {
      value = boolVal
    } else if let stringVal = try? container.decode(String.self) {
      value = stringVal
    } else if let arrayVal = try? container.decode([AnyCodable].self) {
      value = arrayVal
    } else if let dictVal = try? container.decode([String: AnyCodable].self) {
      value = dictVal
    } else {
      value = NSNull()
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case let val as Int:
      try container.encode(val)
    case let val as Double:
      try container.encode(val)
    case let val as Bool:
      try container.encode(val)
    case let val as String:
      try container.encode(val)
    case let val as [AnyCodable]:
      try container.encode(val)
    case let val as [String: AnyCodable]:
      try container.encode(val)
    default:
      try container.encodeNil()
    }
  }
}

final class SupabaseManager: @unchecked Sendable {
  static let shared = SupabaseManager()

  let client: SupabaseClient

  // MARK: - Database Models

  private struct DatabaseUser: Codable {
    let id: String
    let email: String
    let email_confirmed_at: String?
    let phone: String?
    let full_name: String?
    let role: String
    let created_at: String
    let updated_at: String
  }

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

  func resetPasswordForEmail(email: String) async throws {
    do {
      try await client.auth.resetPasswordForEmail(email)
    } catch {
      let description = error.localizedDescription.lowercased()
      if description.contains("not found") || description.contains("no user") {
        throw AuthError.resetEmailNotFound
      }
      throw AuthError.serverError("Failed to send password reset email")
    }
  }

  func updatePassword(newPassword: String) async throws {
    do {
      try await client.auth.update(user: UserAttributes(password: newPassword))
    } catch {
      let description = error.localizedDescription.lowercased()
      if description.contains("invalid") || description.contains("token") {
        throw AuthError.invalidResetToken
      }
      if description.contains("expired") {
        throw AuthError.expiredResetToken
      }
      throw AuthError.serverError("Failed to update password")
    }
  }

  // MARK: - User Profile

  func fetchUserProfile(userId: String) async throws -> User {
    let dbUser: DatabaseUser = try await client
      .from("users")
      .select()
      .eq("id", value: userId)
      .single()
      .execute()
      .value

    return User(
      id: dbUser.id,
      email: dbUser.email,
      emailConfirmedAt: dbUser.email_confirmed_at,
      phone: dbUser.phone,
      createdAt: dbUser.created_at,
      updatedAt: dbUser.updated_at,
      role: UserRole(rawValue: dbUser.role)
    )
  }

  // MARK: - Private Helpers

  private func mapToUser(_ authUser: Supabase.User) -> User {
    // Map userMetadata from Supabase auth user
    let metadata: [String: AnyCodable]? = authUser.userMetadata.isEmpty ? nil : authUser.userMetadata.mapValues { value in
      AnyCodable(value: value)
    }

    // Temporary: Extract role from metadata until database fetch is implemented
    let role: UserRole? = {
      guard let metadata = metadata,
            let roleData = metadata["role"],
            case let roleString as String = roleData.value else {
        return nil
      }
      return UserRole(rawValue: roleString)
    }()

    return User(
      id: authUser.id.uuidString,
      email: authUser.email ?? "",
      emailConfirmedAt: authUser.emailConfirmedAt?.ISO8601Format(),
      phone: authUser.phone,
      createdAt: authUser.createdAt.ISO8601Format(),
      updatedAt: authUser.updatedAt.ISO8601Format(),
      role: role
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
