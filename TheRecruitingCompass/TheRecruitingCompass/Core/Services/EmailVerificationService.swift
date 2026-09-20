import Foundation

enum EmailVerificationServiceError: LocalizedError {
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

/// Parses a Nitro/H3 error response body (`{ "statusMessage": "..." }`).
private struct ServerErrorBody: Decodable {
  let statusMessage: String?
  let message: String?
}

protocol EmailVerificationManaging: Sendable {
  /// Resends the account's verification email. Requires the caller to already
  /// be signed in (server enforces via requireAuth — Bearer token or cookie).
  func resend(accessToken: String) async throws
}

/// REST client for `POST /api/auth/verify-email/resend`, hitting this app's
/// shared backend (`/server/api/**`) — same host/Bearer pattern as
/// `GuardianServiceImpl`. No CSRF token needed: `/api/auth/*` is a
/// CSRF-exempt prefix (server/middleware/csrf.ts), unlike GuardianService's
/// `/api/guardian/*` calls.
struct EmailVerificationServiceImpl: EmailVerificationManaging {
  private let session: URLSession
  private let baseURLOverride: URL?

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }

  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

  func resend(accessToken: String) async throws {
    guard let baseURL else { throw EmailVerificationServiceError.notConfigured }
    var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/verify-email/resend"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw EmailVerificationServiceError.server(-1, message: nil)
    }
    guard (200...299).contains(http.statusCode) else {
      let message = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
      throw EmailVerificationServiceError.server(http.statusCode, message: message?.statusMessage ?? message?.message)
    }
  }
}
