import Foundation
import Supabase

/// Reads and writes marketing email consent through the web API, which owns the timestamp,
/// source (`settings_ios`, derived from the client headers) and the Resend audience sync.
/// The `users` columns are service-role-only, so there is no direct-Supabase path.
struct MarketingConsentServiceImpl: MarketingConsentManaging {
  private static let path = "api/user/marketing-consent"

  private let session: URLSession
  private let baseURLOverride: URL?
  private let accessTokenProvider: @Sendable () async -> String?

  init(
    session: URLSession = .shared,
    baseURLOverride: URL? = nil,
    accessTokenProvider: @escaping @Sendable () async -> String? = {
      try? await SupabaseManager.shared.client.auth.session.accessToken
    }
  ) {
    self.session = session
    self.baseURLOverride = baseURLOverride
    self.accessTokenProvider = accessTokenProvider
  }

  func fetchConsent() async throws -> MarketingConsent {
    try await send(method: "GET", body: nil)
  }

  func updateConsent(optIn: Bool) async throws -> MarketingConsent {
    try await send(method: "PATCH", body: JSONEncoder().encode(["optIn": optIn]))
  }

  private func send(method: String, body: Data?) async throws -> MarketingConsent {
    guard let baseURL = baseURLOverride ?? SupabaseConfig.apiBaseURL else {
      throw MarketingConsentError.notConfigured
    }
    guard let token = await accessTokenProvider(), !token.isEmpty else {
      throw MarketingConsentError.unauthenticated
    }

    var request = URLRequest(url: baseURL.appendingPathComponent(Self.path))
    request.addClientHeaders()
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = body
    }

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw MarketingConsentError.server(-1)
    }
    switch http.statusCode {
    case 200...299:
      return try JSONDecoder().decode(MarketingConsent.self, from: data)
    case 401:
      throw MarketingConsentError.unauthenticated
    case 403:
      throw MarketingConsentError.notEligible
    default:
      throw MarketingConsentError.server(http.statusCode)
    }
  }
}
