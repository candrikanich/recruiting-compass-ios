import Foundation
import OSLog

struct ScorecardMatch: Identifiable, Sendable, Equatable, Decodable {
  var id: Int { scorecardId }
  let scorecardId: Int
  let name: String
  let city: String?
  let state: String?
  let studentSize: Int?
  let admissionRate: Double?
}

enum SchoolEnrichmentError: Error, Equatable {
  case notConfigured, unauthorized, forbidden, server(Int)
}

protocol SchoolEnriching: Sendable {
  func searchMatches(schoolId: String, schoolName: String,
                     accessToken: String?) async throws -> [ScorecardMatch]
  func confirm(schoolId: String, scorecardId: Int,
               accessToken: String?) async throws -> AcademicInfo
}

struct SchoolEnrichmentServiceImpl: SchoolEnriching {
  private let session: URLSession
  private let baseURLOverride: URL?
  private let logger = Logger(subsystem: "com.recruitingcompass", category: "SchoolEnrich")

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }

  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

  // MARK: Decoding wrappers (static → unit-testable without network)

  private struct SearchResponse: Decodable {
    let data: Payload
    struct Payload: Decodable { let matches: [ScorecardMatch] }
  }
  private struct ConfirmResponse: Decodable {
    let data: Payload
    struct Payload: Decodable { let academicInfo: AcademicInfo }
  }

  static func decodeMatches(_ data: Data) throws -> [ScorecardMatch] {
    try JSONDecoder().decode(SearchResponse.self, from: data).data.matches
  }
  static func decodeAcademicInfo(_ data: Data) throws -> AcademicInfo {
    try JSONDecoder().decode(ConfirmResponse.self, from: data).data.academicInfo
  }

  // MARK: API

  func searchMatches(schoolId: String, schoolName: String,
                     accessToken: String?) async throws -> [ScorecardMatch] {
    let data = try await post(schoolId: schoolId, accessToken: accessToken,
                              body: ["schoolName": schoolName])
    return try Self.decodeMatches(data)
  }

  func confirm(schoolId: String, scorecardId: Int,
               accessToken: String?) async throws -> AcademicInfo {
    let data = try await post(schoolId: schoolId, accessToken: accessToken,
                              body: ["scorecardId": scorecardId, "confirmed": true])
    return try Self.decodeAcademicInfo(data)
  }

  private func post(schoolId: String, accessToken: String?,
                    body: [String: Any]) async throws -> Data {
    guard let baseURL, let token = accessToken, !token.isEmpty else {
      throw SchoolEnrichmentError.notConfigured
    }
    let csrf = try await fetchCSRFToken(baseURL: baseURL)
    let safeId = schoolId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? schoolId
    let url = baseURL.appendingPathComponent("api/schools").appendingPathComponent(safeId)
      .appendingPathComponent("enrich")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await session.data(for: request)
    try Self.mapStatus(response)
    return data
  }

  private static func mapStatus(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else { throw SchoolEnrichmentError.server(-1) }
    switch http.statusCode {
    case 200...299: return
    case 401: throw SchoolEnrichmentError.unauthorized
    case 403: throw SchoolEnrichmentError.forbidden
    default: throw SchoolEnrichmentError.server(http.statusCode)
    }
  }

  /// Copies PublicProfileServiceImpl.fetchCSRFToken: GET /api/csrf-token, read csrf-token cookie.
  private func fetchCSRFToken(baseURL: URL) async throws -> String {
    let url = baseURL.appendingPathComponent("api/csrf-token")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      logger.error("CSRF token request failed")
      throw SchoolEnrichmentError.server(-1)
    }
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrfCookie = cookies.first(where: { $0.name == "csrf-token" }) else {
      logger.error("No csrf-token cookie in storage after GET /api/csrf-token")
      throw SchoolEnrichmentError.server(-1)
    }
    return csrfCookie.value
  }
}
