import Foundation
import OSLog

/// Pre-send guardrail signals returned by `POST /api/athlete/messages/check`.
struct SendCheckResult: Decodable, Equatable, Sendable {
  let programNoteReused: Bool
  let daysSinceLastContact: Int?
  let recentContact: Bool
  let messageCountToSchool: Int
}

struct SendCheckInput: Encodable {
  let athleteUserId: String
  let schoolId: String?
  let programNote: String?
}

struct LogMessageInput: Encodable {
  let athleteUserId: String
  let schoolId: String?
  let coachId: String?
  let templateSlug: String?
  let channel: String?
  let programNote: String?
  let updateHook: String?
  let subject: String?
  let body: String?
}

enum AthleteMessagesError: Error { case notConfigured, server(Int) }

protocol AthleteMessagesServicing: Sendable {
  func checkSend(_ input: SendCheckInput, accessToken: String?) async throws -> SendCheckResult
  func logSend(_ input: LogMessageInput, accessToken: String?) async throws
}

/// Coach-outreach guardrail check + best-effort send logging via the web API.
/// Bearer + `x-csrf-token` (mirrors `PublicProfileServiceImpl`). Callers fail-open.
struct AthleteMessagesServiceImpl: AthleteMessagesServicing {
  private let session: URLSession
  private let baseURLOverride: URL?
  private let logger = Logger(subsystem: "com.recruitingcompass", category: "AthleteMessages")

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }
  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

  func checkSend(_ input: SendCheckInput, accessToken: String?) async throws -> SendCheckResult {
    let data = try await post("api/athlete/messages/check", body: input, accessToken: accessToken)
    return try JSONDecoder().decode(SendCheckResult.self, from: data)
  }

  func logSend(_ input: LogMessageInput, accessToken: String?) async throws {
    _ = try await post("api/athlete/messages", body: input, accessToken: accessToken)
  }

  private func post<B: Encodable>(_ path: String, body: B, accessToken: String?) async throws -> Data {
    guard let baseURL, let token = accessToken, !token.isEmpty else {
      throw AthleteMessagesError.notConfigured
    }
    let csrf = try await fetchCSRFToken(baseURL: baseURL)
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
    request.httpBody = try JSONEncoder().encode(body)
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw AthleteMessagesError.server((response as? HTTPURLResponse)?.statusCode ?? -1)
    }
    return data
  }

  /// Port of `PublicProfileServiceImpl.fetchCSRFToken` (GET /api/csrf-token → csrf-token cookie).
  private func fetchCSRFToken(baseURL: URL) async throws -> String {
    var request = URLRequest(url: baseURL.appendingPathComponent("api/csrf-token"))
    request.httpMethod = "GET"
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw AthleteMessagesError.server(-1)
    }
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrf = cookies.first(where: { $0.name == "csrf-token" }) else {
      throw AthleteMessagesError.server(-1)
    }
    return csrf.value
  }
}
