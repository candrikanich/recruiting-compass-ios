import Foundation
import Supabase
import Helpers
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SupabaseManager"
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

/// @unchecked Sendable: Wraps the Supabase Swift SDK's SupabaseClient,
/// which is not Sendable but is designed for concurrent use. All operations
/// delegate to the underlying client which handles its own thread safety.
/// This is a standard pattern when wrapping non-Sendable SDK types that
/// are documented as thread-safe by the vendor.
final class SupabaseManager: SupabaseManaging, @unchecked Sendable {
  static let shared = SupabaseManager()

  let client: SupabaseClient

  // MARK: - Database Models

  private struct DatabaseUser: Codable {
    let id: String
    let email: String
    let emailConfirmedAt: String?
    let phone: String?
    let fullName: String?
    let role: String
    let createdAt: String
    let updatedAt: String
    let dateOfBirth: String?
    let profilePhotoUrl: String?

    enum CodingKeys: String, CodingKey {
      case id
      case email
      case emailConfirmedAt = "email_confirmed_at"
      case phone
      case fullName = "full_name"
      case role
      case createdAt = "created_at"
      case updatedAt = "updated_at"
      case dateOfBirth = "date_of_birth"
      case profilePhotoUrl = "profile_photo_url"
    }
  }

  /// Payload for upserting into public.users. Mirrors web signup flow.
  private struct UsersUpsertPayload: Encodable {
    let id: String
    let email: String
    let fullName: String
    let role: String

    enum CodingKeys: String, CodingKey {
      case id, email, role
      case fullName = "full_name"
    }
  }

  private static let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    return f
  }()

  private init() {
    self.client = SupabaseClient(
      supabaseURL: SupabaseConfig.url,
      supabaseKey: SupabaseConfig.anonKey,
      options: SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
      )
    )
  }

  // MARK: - Authentication

  func setSession(accessToken: String, refreshToken: String) async throws {
    _ = try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
  }

  func signIn(email: String, password: String) async throws -> (user: User, session: Session) {
    let response = try await client.auth.signIn(
      email: email,
      password: password
    )

    // Fetch user profile from database with retry
    guard let user = try await fetchUserProfileWithRetry(
      userId: response.user.id.uuidString,
      email: response.user.email ?? email,
      fallbackMetadata: response.user.userMetadata
    ) else {
      throw AuthError.serverError("Failed to fetch user profile")
    }

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

    do {
      let response = try await client.auth.signUp(
        email: email,
        password: password,
        data: metadata
      )

      let userId = response.user.id.uuidString
      let userEmail = response.user.email ?? email

      // Upsert users row (mirrors web signup). Required for user_preferences FK.
      try await client
        .from("users")
        .upsert(
          UsersUpsertPayload(
            id: userId,
            email: userEmail,
            fullName: fullName,
            role: role.rawValue
          ),
          onConflict: "id"
        )
        .execute()

      // Try to fetch from database, fall back to metadata for new users
      let user = try await fetchUserProfileWithRetry(
        userId: userId,
        email: userEmail,
        fallbackMetadata: response.user.userMetadata
      ) ?? User(
        id: userId,
        email: userEmail,
        emailConfirmedAt: nil,
        phone: nil,
        fullName: fullName,
        createdAt: Self.isoFormatter.string(from: Date.now),
        updatedAt: Self.isoFormatter.string(from: Date.now),
        role: role,
        dateOfBirth: nil
      )

      let session = response.session.map { mapToSession($0, user: user) }

      return (user, session)
    } catch {
      throw mapSupabaseSignUpError(error)
    }
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

      guard let user = try await fetchUserProfileWithRetry(
        userId: authSession.user.id.uuidString,
        email: authSession.user.email ?? "",
        fallbackMetadata: authSession.user.userMetadata
      ) else {
        throw AuthError.serverError("Failed to fetch user profile")
      }

      return mapToSession(authSession, user: user)
    } catch let authError as AuthError {
      throw authError
    } catch {
      throw AuthError.unknown(error)
    }
  }

  func refreshSession() async throws -> User {
    let authSession = try await client.auth.session

    guard let user = try await fetchUserProfileWithRetry(
      userId: authSession.user.id.uuidString,
      email: authSession.user.email ?? "",
      fallbackMetadata: authSession.user.userMetadata
    ) else {
      throw AuthError.serverError("Failed to fetch user profile")
    }

    return user
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
      guard SupabaseAuthErrors.isUserNotFound(error) else {
        throw AuthError.serverError("Failed to send password reset email")
      }
      throw AuthError.resetEmailNotFound
    }
  }

  func updatePassword(newPassword: String) async throws {
    do {
      try await client.auth.update(user: UserAttributes(password: newPassword))
    } catch {
      if SupabaseAuthErrors.isInvalidToken(error) {
        throw AuthError.invalidResetToken
      }
      if SupabaseAuthErrors.isExpiredToken(error) {
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
      emailConfirmedAt: dbUser.emailConfirmedAt,
      phone: dbUser.phone,
      fullName: dbUser.fullName,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
      role: UserRole(rawValue: dbUser.role),
      dateOfBirth: dbUser.dateOfBirth,
      profilePhotoUrl: dbUser.profilePhotoUrl
    )
  }

  func fetchUserProfileWithRetry(
    userId: String,
    email: String,
    fallbackMetadata: [String: AnyJSON]?
  ) async throws -> User? {
    let maxRetries = 3
    let retryDelays: [Duration] = [.milliseconds(500), .seconds(1), .seconds(2)]

    for attempt in 0..<maxRetries {
      do {
        let user = try await fetchUserProfile(userId: userId)
        logger.info("Successfully fetched user profile for \(userId, privacy: .private)")
        return user
      } catch {
        logger.warning("Attempt \(attempt + 1)/\(maxRetries) failed: \(error.localizedDescription)")
        if attempt < maxRetries - 1 {
          try? await Task.sleep(for: retryDelays[attempt])
        }
      }
    }

    // Fallback to metadata if all retries failed
    logger.error("All retries failed for user \(userId, privacy: .private), falling back to metadata")
    guard let user = createUserFromMetadata(userId: userId, email: email, metadata: fallbackMetadata) else {
      return nil
    }
    // Upsert user into users so user_preferences FK is satisfied (e.g. during onboarding)
    do {
      try await client
        .from("users")
        .upsert(
          UsersUpsertPayload(
            id: user.id,
            email: user.email,
            fullName: user.fullName ?? "",
            role: user.role?.rawValue ?? UserRole.player.rawValue
          ),
          onConflict: "id"
        )
        .execute()
      logger.info("Upserted user \(userId, privacy: .private) into users table from metadata fallback")
    } catch {
      logger.error("Failed to upsert user from metadata: \(error.localizedDescription)")
      // users_id_fkey: auth user was deleted (e.g. from Supabase dashboard) but app has stale session
      let errDesc = (error as NSError).localizedDescription
      if errDesc.contains("users_id_fkey") {
        try? await client.auth.signOut()
        throw AuthError.sessionInvalid
      }
      // Other upsert errors: still return user; preferences save may fail
    }
    return user
  }

  // MARK: - Private Helpers

  private func createUserFromMetadata(
    userId: String,
    email: String,
    metadata: [String: AnyJSON]?
  ) -> User? {
    guard let metadata = metadata,
          let roleData = metadata["role"],
          case let roleString as String = roleData.value,
          let role = UserRole(rawValue: roleString) else {
      return nil
    }

    let fullName: String? = metadata["full_name"].flatMap { data in
      if case let s as String = data.value { return s }
      return nil
    }

    return User(
      id: userId,
      email: email,
      emailConfirmedAt: nil,
      phone: nil,
      fullName: fullName,
      createdAt: Self.isoFormatter.string(from: Date.now),
      updatedAt: Self.isoFormatter.string(from: Date.now),
      role: role,
      dateOfBirth: nil
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

  /// Maps Supabase Auth / network errors from signUp to app AuthError for user-facing messages.
  private func mapSupabaseSignUpError(_ error: Error) -> AuthError {
    if let authError = error as? AuthError {
      return authError
    }
    let ns = error as NSError
    let msg = (ns.userInfo[NSLocalizedDescriptionKey] as? String) ?? error.localizedDescription
    let lower = msg.lowercased()

    // Network / connection (placeholder URL, no network, etc.)
    if ns.domain == NSURLErrorDomain {
      let suggestion = lower.contains("placeholder") || ns.code == NSURLErrorCannotFindHost
        ? " Check that SUPABASE_URL and SUPABASE_ANON_KEY are set in Scheme → Run → Environment Variables."
        : ""
      return .networkError("Could not reach the server.\(suggestion)")
    }
    if lower.contains("could not connect") || lower.contains("network") || lower.contains("connection") {
      return .networkError("Could not reach the server. Check your connection and try again.")
    }

    // Supabase Auth API semantics (match common codes/descriptions)
    if lower.contains("already exists") || lower.contains("user_already_exists") || lower.contains("email_exists") {
      return .emailAlreadyRegistered
    }
    if lower.contains("weak password") || lower.contains("password") && lower.contains("strength") {
      return .passwordTooWeak
    }
    if lower.contains("invalid email") || lower.contains("email_address_invalid") || lower.contains("validation_failed") {
      return .invalidEmail
    }
    if lower.contains("rate limit") || lower.contains("too many") || lower.contains("429") {
      return .tooManyAttempts(retryAfter: nil)
    }

    return .unknown(error)
  }
}
