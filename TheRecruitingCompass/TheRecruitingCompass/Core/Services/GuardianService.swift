import Foundation
import OSLog

enum GuardianServiceError: LocalizedError {
  case notConfigured
  case server(Int, message: String?)

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "Could not reach the server. Please try again."
    case .server(_, let message):
      return message ?? "Something went wrong. Please try again."
    }
  }
}

/// Request body for `POST /api/auth/signup-minor`.
private struct SignupMinorBody: Encodable {
  let email: String
  let password: String
  let firstName: String
  let lastName: String
  let dateOfBirth: String
  let guardianEmail: String
  let captchaToken: String?
}

private struct ResendBody: Encodable {
  let guardianEmail: String?
}

/// Parses a Nitro/H3 error response body (`{ "statusMessage": "..." }`) so a
/// rejected request can surface its real reason instead of a generic string.
private struct ServerErrorBody: Decodable {
  let statusMessage: String?
  let message: String?
}

protocol GuardianManaging: Sendable {
  /// Standalone signup for a 13-17 player who names a guardian. No session
  /// is returned — email confirmation is required exactly like the ordinary
  /// signup path.
  func signupMinor(
    email: String, password: String, firstName: String, lastName: String,
    dateOfBirth: String, guardianEmail: String, captchaToken: String?
  ) async throws -> SignupMinorResult

  /// Guardian-confirmation status for the signed-in player.
  func fetchStatus(accessToken: String) async throws -> GuardianStatus

  /// Resends the guardian confirmation email, optionally to a new address.
  func resend(accessToken: String, guardianEmail: String?) async throws

  /// Resolves a claim token for the guardian's confirmation page. Public —
  /// the guardian may not have an account yet.
  func resolveClaim(token: String) async throws -> GuardianClaimDetails

  /// Confirms a claim. Requires the guardian to be signed in with the
  /// matching email — enforced server-side.
  func acceptClaim(token: String, accessToken: String) async throws -> GuardianClaimAcceptResult
}

/// REST client for the guardian-linked-signup feature, hitting this app's
/// shared backend (`/server/api/**`) — the same host and CSRF/Bearer pattern
/// as `AthleteMessagesServiceImpl`/`PublicProfileServiceImpl`.
struct GuardianServiceImpl: GuardianManaging {
  private let session: URLSession
  private let baseURLOverride: URL?
  private let logger = Logger(subsystem: "com.recruitingcompass", category: "GuardianService")

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }

  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

  func signupMinor(
    email: String, password: String, firstName: String, lastName: String,
    dateOfBirth: String, guardianEmail: String, captchaToken: String?
  ) async throws -> SignupMinorResult {
    let body = SignupMinorBody(
      email: email, password: password, firstName: firstName, lastName: lastName,
      dateOfBirth: dateOfBirth, guardianEmail: guardianEmail, captchaToken: captchaToken)
    let data = try await request("api/auth/signup-minor", method: "POST", body: body, accessToken: nil)
    return try JSONDecoder().decode(SignupMinorResult.self, from: data)
  }

  func fetchStatus(accessToken: String) async throws -> GuardianStatus {
    let data = try await request("api/guardian/status", method: "GET", body: Optional<Int>.none, accessToken: accessToken)
    return try JSONDecoder().decode(GuardianStatus.self, from: data)
  }

  func resend(accessToken: String, guardianEmail: String?) async throws {
    let body = ResendBody(guardianEmail: guardianEmail)
    _ = try await request("api/guardian/resend", method: "POST", body: body, accessToken: accessToken)
  }

  func resolveClaim(token: String) async throws -> GuardianClaimDetails {
    let escaped = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
    let data = try await request("api/guardian/claim/\(escaped)", method: "GET", body: Optional<Int>.none, accessToken: nil)
    return try JSONDecoder().decode(GuardianClaimDetails.self, from: data)
  }

  func acceptClaim(token: String, accessToken: String) async throws -> GuardianClaimAcceptResult {
    let escaped = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
    let data = try await request("api/guardian/claim/\(escaped)/accept", method: "POST", body: Optional<Int>.none, accessToken: accessToken)
    return try JSONDecoder().decode(GuardianClaimAcceptResult.self, from: data)
  }

  // MARK: - Networking

  private func request<B: Encodable>(
    _ path: String, method: String, body: B?, accessToken: String?
  ) async throws -> Data {
    guard let baseURL else { throw GuardianServiceError.notConfigured }
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = method
    if let accessToken {
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    if let body {
      let csrf = try? await fetchCSRFToken(baseURL: baseURL)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      if let csrf { request.setValue(csrf, forHTTPHeaderField: "x-csrf-token") }
      request.httpBody = try JSONEncoder().encode(body)
    }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw GuardianServiceError.server(-1, message: nil)
    }
    guard (200...299).contains(http.statusCode) else {
      let message = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
      throw GuardianServiceError.server(http.statusCode, message: message?.statusMessage ?? message?.message)
    }
    return data
  }

  /// Port of `AthleteMessagesServiceImpl.fetchCSRFToken` (GET /api/csrf-token → cookie).
  private func fetchCSRFToken(baseURL: URL) async throws -> String {
    var request = URLRequest(url: baseURL.appendingPathComponent("api/csrf-token"))
    request.httpMethod = "GET"
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw GuardianServiceError.server(-1, message: nil)
    }
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrf = cookies.first(where: { $0.name == "csrf-token" }) else {
      throw GuardianServiceError.server(-1, message: nil)
    }
    return csrf.value
  }
}
