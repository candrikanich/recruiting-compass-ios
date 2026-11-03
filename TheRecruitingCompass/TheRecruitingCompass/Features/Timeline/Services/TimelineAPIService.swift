import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "TimelineAPIService")

/// Errors surfaced by the shared timeline endpoints.
enum TimelineAPIError: Error {
  case notConfigured
  case unauthorized
  case invalidResponse
  case http(Int)
}

/// Fetches phase / status / what-matters-now from the web app. Stateless and
/// Sendable — mirrors `DashboardServiceImpl`'s authed-GET pattern (Bearer token,
/// 401→`unauthorized`, JSON decode).
final class TimelineAPIService: TimelineAPIManaging, Sendable {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchPhase(accessToken: String?, athleteId: String?) async throws -> AthletePhaseResponse {
    try await get("api/athlete/phase", accessToken: accessToken, athleteId: athleteId)
  }

  func fetchStatus(accessToken: String?, athleteId: String?) async throws -> AthleteStatusResponse {
    try await get("api/athlete/status", accessToken: accessToken, athleteId: athleteId)
  }

  func fetchWhatMattersNow(accessToken: String?, athleteId: String?) async throws -> [WhatMattersItem] {
    try await get("api/athlete/what-matters-now", accessToken: accessToken, athleteId: athleteId)
  }

  /// Without `athleteId` the server picks the athlete closest to graduation across ALL of a parent's families,
  /// so a parent must always send the selected athlete or this screen shows another family's data.
  private func get<T: Decodable>(_ path: String, accessToken: String?, athleteId: String?) async throws -> T {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      logger.error("Timeline API not configured (API_BASE_URL missing)")
      throw TimelineAPIError.notConfigured
    }
    guard let token = accessToken, !token.isEmpty else {
      throw TimelineAPIError.unauthorized
    }

    var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
    components?.queryItems = athleteId.map { [URLQueryItem(name: "athleteId", value: $0)] }
    guard let url = components?.url else { throw TimelineAPIError.notConfigured }
    var request = URLRequest(url: url)
    request.addClientHeaders()
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await session.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw TimelineAPIError.invalidResponse
    }
    guard http.statusCode == 200 else {
      logger.error("\(path) returned \(http.statusCode)")
      if http.statusCode == 401 { throw TimelineAPIError.unauthorized }
      throw TimelineAPIError.http(http.statusCode)
    }

    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      logger.error("Failed to decode \(path): \(String(describing: error))")
      throw error
    }
  }
}
