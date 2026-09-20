import Foundation
import Supabase
import Helpers
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SupabaseManager"
)

/// @unchecked Sendable: Wraps the Supabase Swift SDK's SupabaseClient,
/// which is not Sendable but is designed for concurrent use. All operations
/// delegate to the underlying client which handles its own thread safety.
/// This is a standard pattern when wrapping non-Sendable SDK types that
/// are documented as thread-safe by the vendor.
final class SupabaseManager: SupabaseManaging, @unchecked Sendable {
  static let shared = SupabaseManager()

  let client: SupabaseClient

  // MARK: - Database Models

  private nonisolated struct DatabaseUser: Codable {
    let id: String
    let email: String
    let emailConfirmedAt: String?
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
    let dateOfBirth: String?

    enum CodingKeys: String, CodingKey {
      case id, email, role
      case fullName = "full_name"
      case dateOfBirth = "date_of_birth"
    }
  }

  /// Request body for `POST /api/auth/signup` — mirrors `SignupBody` in
  /// server/api/auth/signup.post.ts. That endpoint (not the Supabase SDK) owns
  /// account creation and the custom verification email for every platform;
  /// calling Supabase Auth directly here would bypass sendVerificationEmail()
  /// entirely, which is what left iOS parent signups with no verification email.
  private struct WebSignupBody: Encodable {
    let email: String
    let password: String
    let fullName: String
    let role: String
    let dateOfBirth: String?
    let captchaToken: String
    let metadata: [String: String]
  }

  private struct WebSignupResult: Decodable {
    let userId: String
    /// Service-role magiclink token, present when minting succeeds server-side.
    /// Consumed via `client.auth.verifyOTP(tokenHash:type:)` to establish the
    /// session with no second CAPTCHA hop. Falls back to a fresh-token
    /// `signIn` when absent (mirrors composables/useAuth.ts on web).
    let tokenHash: String?
  }

  /// Parses a Nitro/H3 error response body (`{ "statusMessage": "..." }`).
  private struct WebSignupErrorBody: Decodable {
    let statusMessage: String?
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

  func signIn(email: String, password: String, captchaToken: String) async throws -> (user: User, session: Session) {
    let response = try await client.auth.signIn(
      email: email,
      password: password,
      captchaToken: captchaToken
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
    familyCode: String?,
    dateOfBirth: String? = nil,
    graduationYear: Int? = nil,
    primarySport: String? = nil,
    gender: String? = nil,
    zipCode: String? = nil,
    captchaToken: String
  ) async throws -> (user: User, session: Session?) {
    // family_code isn't accepted by the web signup endpoint's metadata (server/api/auth/signup.post.ts
    // ALLOWED_METADATA_KEYS) — family creation is its own step after signup (see
    // SignupViewModel.signup(), which already passes familyCode: nil here and calls
    // familyService.createFamily(role:) afterward, mirroring web's flow).
    _ = familyCode

    // Carried across the email-confirmation gap and flushed into real preferences by
    // AccountProvisioningService on first authenticated session. See planning/iOS_SPEC_preconfirm-onboarding-step1-2026-09-11.md.
    var metadata: [String: String] = [:]
    if let graduationYear {
      metadata["pending_graduation_year"] = String(graduationYear)
    }
    if let primarySport, !primarySport.isEmpty {
      metadata["pending_primary_sport"] = primarySport
    }
    if let gender, !gender.isEmpty {
      metadata["pending_gender"] = gender
    }
    if let zipCode, !zipCode.isEmpty {
      metadata["pending_zip_code"] = zipCode
    }

    let created = try await createAccountViaWebSignup(
      WebSignupBody(
        email: email,
        password: password,
        fullName: fullName,
        role: role.rawValue,
        dateOfBirth: (dateOfBirth?.isEmpty == false) ? dateOfBirth : nil,
        captchaToken: captchaToken,
        metadata: metadata
      )
    )

    // The account is already committed and auto-confirmed at this point. Everything
    // below only establishes/persists local session state, so its failures must not
    // read as "signup failed" (retrying would hit the server's deliberately generic
    // duplicate-account response for an email that's now actually taken) — tag them
    // as AuthError.accountCreatedButSignInFailed instead, mirroring useAuth.ts's
    // `accountCreatedButSignInFailed` flag on web.
    do {
      let authSession: Supabase.Session
      if let tokenHash = created.tokenHash {
        guard case .session(let session) = try await client.auth.verifyOTP(
          tokenHash: tokenHash,
          type: .magiclink
        ) else {
          throw AuthError.serverError("Sign-in did not return a session")
        }
        authSession = session
      } else {
        // Fallback for the rare case the server couldn't mint a tokenHash: the
        // signup captchaToken was already consumed by the endpoint's own check,
        // so a fresh one is needed here.
        let freshCaptchaToken = try await TurnstileTokenProvider.shared.getToken()
        authSession = try await client.auth.signIn(
          email: email,
          password: password,
          captchaToken: freshCaptchaToken
        )
      }

      let userEmail = authSession.user.email ?? email

      // Upsert users row (mirrors web signup). Defensive fallback alongside the
      // handle_new_user() DB trigger, which already creates this row server-side —
      // so a failure here (e.g. a transient RLS/grant hiccup on the upsert's
      // ON CONFLICT DO UPDATE path) must not read as "signup failed": the account
      // is already committed (see comment above), the trigger already covers the
      // row, and fetchUserProfileWithRetry below has its own metadata fallback.
      do {
        try await client
          .from("users")
          .upsert(
            UsersUpsertPayload(
              id: created.userId,
              email: userEmail,
              fullName: fullName,
              role: role.rawValue,
              dateOfBirth: dateOfBirth
            ),
            onConflict: "id"
          )
          .execute()
      } catch {
        logger.warning("Non-fatal: users upsert after signup failed: \(error.localizedDescription)")
      }

      // Try to fetch from database, fall back to metadata for new users
      let user = try await fetchUserProfileWithRetry(
        userId: created.userId,
        email: userEmail,
        fallbackMetadata: authSession.user.userMetadata
      ) ?? User(
        id: created.userId,
        email: userEmail,
        emailConfirmedAt: nil,
        fullName: fullName,
        createdAt: Self.isoFormatter.string(from: Date.now),
        updatedAt: Self.isoFormatter.string(from: Date.now),
        role: role,
        dateOfBirth: nil
      )

      let session = mapToSession(authSession, user: user)

      return (user, session)
    } catch {
      throw AuthError.accountCreatedButSignInFailed(mapSupabaseSignUpError(error).errorDescription ?? "Sign-in failed")
    }
  }

  /// Calls the web app's `POST /api/auth/signup` — the account-creation and
  /// verification-email owner for every platform (server/utils/accountCreation.ts).
  /// `/api/auth/*` is CSRF-exempt (server/middleware/csrf.ts) so no CSRF token is needed.
  private func createAccountViaWebSignup(_ body: WebSignupBody) async throws -> WebSignupResult {
    do {
      guard let baseURL = SupabaseConfig.apiBaseURL else {
        throw AuthError.networkError("Could not reach the server.")
      }
      var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/signup"))
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(body)

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        throw AuthError.networkError("Could not reach the server.")
      }
      guard (200...299).contains(http.statusCode) else {
        if http.statusCode == 403 {
          throw AuthError.captchaFailed
        }
        if http.statusCode == 429 {
          throw AuthError.tooManyAttempts(retryAfter: nil)
        }
        // 400 is deliberately generic server-side — duplicate-email and other creation
        // failures are indistinguishable (accountCreation.ts) to avoid an
        // account-existence-enumeration oracle. Surface the server's message as-is.
        let errorBody = try? JSONDecoder().decode(WebSignupErrorBody.self, from: data)
        throw AuthError.serverError(errorBody?.statusMessage ?? "Unable to create account. Please try again.")
      }
      return try JSONDecoder().decode(WebSignupResult.self, from: data)
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

  func resendVerificationEmail(email: String, captchaToken: String) async throws {
    do {
      try await client.auth.resend(
        email: email,
        type: .signup,
        captchaToken: captchaToken
      )
    } catch {
      throw AuthError.serverError("Failed to resend verification email")
    }
  }

  func resetPasswordForEmail(email: String, captchaToken: String) async throws {
    do {
      try await client.auth.resetPasswordForEmail(email, captchaToken: captchaToken)
    } catch {
      guard SupabaseAuthErrors.isUserNotFound(error) else {
        throw AuthError.serverError("Failed to send password reset email")
      }
      throw AuthError.resetEmailNotFound
    }
  }

  func currentUserMetadata() async -> [String: AnyJSON]? {
    try? await client.auth.session.user.userMetadata
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
            role: user.role?.rawValue ?? UserRole.player.rawValue,
            dateOfBirth: user.dateOfBirth
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

    let dateOfBirth: String? = metadata["date_of_birth"].flatMap { data in
      if case let s as String = data.value { return s }
      return nil
    }

    return User(
      id: userId,
      email: email,
      emailConfirmedAt: nil,
      fullName: fullName,
      createdAt: Self.isoFormatter.string(from: Date.now),
      updatedAt: Self.isoFormatter.string(from: Date.now),
      role: role,
      dateOfBirth: dateOfBirth
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
