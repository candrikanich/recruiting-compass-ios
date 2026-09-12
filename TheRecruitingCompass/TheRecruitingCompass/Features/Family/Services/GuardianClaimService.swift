import Foundation
import OSLog

/// Guardian-confirmation state for the signed-in player, as returned by
/// `GET /api/guardian/status`. Mirrors the web `GuardianStatus` type.
///
/// Never carries the claim token: it is the guardian's authorization to consent, and a
/// minor holding it could confirm their own account.
struct GuardianStatus: Decodable, Equatable, Sendable {
  /// True while an unconfirmed claim is outstanding — outbound features stay locked.
  let pending: Bool
  /// Obfuscated for display (`j***@example.com`); the full address never reaches the client.
  let guardianEmailMasked: String?
  let expiresAt: String?
  let status: String?
}

/// Payload for `POST /api/auth/signup-minor`. Unauthenticated — the player has no account
/// yet, which is the point.
struct MinorSignupInput: Encodable, Sendable {
  let email: String
  let password: String
  let firstName: String
  let lastName: String
  let dateOfBirth: String
  let guardianEmail: String
  let graduationYear: Int?
  let primarySport: String?
  let gender: String?
  let zipCode: String?
  let captchaToken: String?
}

enum GuardianClaimError: LocalizedError {
  /// `API_BASE_URL` is unset, so the web API is unreachable from this build.
  case notConfigured
  case server(status: Int, message: String?)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "Signing up as a player under 18 isn't available in this build."
    case .server(_, let message):
      return message ?? "Something went wrong. Please try again."
    }
  }
}

protocol GuardianClaimServicing: Sendable {
  /// True when this build can reach the web API at all. Callers must check before offering
  /// the minor signup path, so an unconfigured build explains itself instead of failing
  /// at submit time.
  var isConfigured: Bool { get }
  func signupMinor(_ input: MinorSignupInput) async throws
  func status(accessToken: String?) async throws -> GuardianStatus
  func resend(guardianEmail: String?, accessToken: String?) async throws
}

/// Guardian-linked signup and confirmation via the web API.
/// Bearer + `x-csrf-token`, mirroring `AthleteMessagesServiceImpl`.
struct GuardianClaimServiceImpl: GuardianClaimServicing {
  private let session: URLSession
  private let baseURLOverride: URL?
  private let logger = Logger(subsystem: "com.recruitingcompass", category: "GuardianClaim")

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }

  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }
  var isConfigured: Bool { baseURL != nil }

  func signupMinor(_ input: MinorSignupInput) async throws {
    _ = try await send("api/auth/signup-minor", method: "POST", body: input, accessToken: nil)
  }

  func status(accessToken: String?) async throws -> GuardianStatus {
    let data = try await send(
      "api/guardian/status",
      method: "GET",
      body: Optional<MinorSignupInput>.none,
      accessToken: accessToken
    )
    return try JSONDecoder().decode(GuardianStatus.self, from: data)
  }

  func resend(guardianEmail: String?, accessToken: String?) async throws {
    struct Body: Encodable { let guardianEmail: String? }
    _ = try await send(
      "api/guardian/resend",
      method: "POST",
      body: Body(guardianEmail: guardianEmail),
      accessToken: accessToken
    )
  }

  private func send<B: Encodable>(
    _ path: String,
    method: String,
    body: B?,
    accessToken: String?
  ) async throws -> Data {
    guard let baseURL else { throw GuardianClaimError.notConfigured }

    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let accessToken, !accessToken.isEmpty {
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    if method != "GET" {
      // `/api/auth/**` is CSRF-exempt server-side (CSRF_EXEMPT_PREFIXES in
      // server/middleware/csrf.ts) because it serves callers with no session and therefore
      // no token. Fetching one anyway would add a round-trip and a failure mode to the one
      // request made before the player has an account.
      if !path.hasPrefix("api/auth/") {
        request.setValue(
          try await fetchCSRFToken(baseURL: baseURL),
          forHTTPHeaderField: "x-csrf-token"
        )
      }
      if let body { request.httpBody = try JSONEncoder().encode(body) }
    }

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw GuardianClaimError.server(status: -1, message: nil)
    }
    guard (200...299).contains(http.statusCode) else {
      // Nitro puts the user-facing reason in `statusMessage`; surfacing it keeps the
      // wording identical to web instead of inventing a second set of strings.
      let message = (try? JSONDecoder().decode(NitroError.self, from: data))?.statusMessage
      logger.error("Guardian request failed: \(http.statusCode, privacy: .public)")
      throw GuardianClaimError.server(status: http.statusCode, message: message)
    }
    return data
  }

  private struct NitroError: Decodable { let statusMessage: String? }

  /// Port of `AthleteMessagesServiceImpl.fetchCSRFToken` (GET /api/csrf-token → cookie).
  private func fetchCSRFToken(baseURL: URL) async throws -> String {
    var request = URLRequest(url: baseURL.appendingPathComponent("api/csrf-token"))
    request.httpMethod = "GET"
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw GuardianClaimError.server(status: -1, message: nil)
    }
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrf = cookies.first(where: { $0.name == "csrf-token" }) else {
      throw GuardianClaimError.server(status: -1, message: nil)
    }
    return csrf.value
  }
}
