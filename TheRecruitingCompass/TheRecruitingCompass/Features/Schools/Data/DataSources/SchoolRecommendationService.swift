import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolRecommendationService")

protocol SchoolRecommendationManaging: Sendable {
  func fetchRecommendations(athleteId: String, limit: Int) async throws -> [SchoolRecommendation]
  func dismissRecommendation(catalogKey: String, athleteId: String) async throws
}

/// Sendable: Stateless service with no mutable properties
final class SchoolRecommendationServiceImpl: SchoolRecommendationManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchRecommendations(athleteId: String, limit: Int) async throws -> [SchoolRecommendation] {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      logger.debug("API_BASE_URL not configured, returning empty recommendations")
      return []
    }

    guard let session = try? await supabaseManager.client.auth.session else {
      logger.debug("No auth session, returning empty recommendations")
      return []
    }

    guard var components = URLComponents(
      url: baseURL.appendingPathComponent("api/schools/recommendations"),
      resolvingAgainstBaseURL: false
    ) else {
      logger.error("Failed to build recommendations URL")
      return []
    }

    components.queryItems = [
      URLQueryItem(name: "athleteId", value: athleteId),
      URLQueryItem(name: "limit", value: String(limit))
    ]

    guard let url = components.url else {
      logger.error("Failed to construct recommendations URL from components")
      return []
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw SchoolRecommendationError.invalidResponse
    }

    guard http.statusCode == 200 else {
      logger.error("Recommendations API returned \(http.statusCode)")
      throw SchoolRecommendationError.serverError(http.statusCode)
    }

    guard !data.isEmpty else {
      logger.debug("Recommendations API returned empty body")
      return []
    }

    do {
      let result = try JSONDecoder().decode(RecommendationsResponse.self, from: data)
      logger.info("Fetched \(result.recommendations.count) school recommendations")
      return result.recommendations
    } catch let error as DecodingError {
      logger.warning("Recommendations decode failed: \(String(describing: error)). Treating as empty.")
      return []
    }
  }

  func dismissRecommendation(catalogKey: String, athleteId: String) async throws {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      logger.debug("API_BASE_URL not configured, skipping dismiss")
      return
    }

    guard let session = try? await supabaseManager.client.auth.session else {
      logger.warning("No auth session, skipping dismiss")
      return
    }

    let url = baseURL.appendingPathComponent("api/schools/recommendations/dismiss")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload = try JSONEncoder().encode(DismissPayload(catalogKey: catalogKey, athleteId: athleteId))
    request.httpBody = payload

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw SchoolRecommendationError.invalidResponse
    }

    guard http.statusCode == 200 else {
      logger.error("Dismiss recommendation returned \(http.statusCode)")
      throw SchoolRecommendationError.serverError(http.statusCode)
    }

    logger.info("Dismissed recommendation: \(catalogKey)")
  }
}

private struct RecommendationsResponse: Decodable {
  let recommendations: [SchoolRecommendation]
}

private struct DismissPayload: Encodable {
  let catalogKey: String
  let athleteId: String

  enum CodingKeys: String, CodingKey {
    case catalogKey = "catalog_key"
    case athleteId = "athlete_id"
  }
}

enum SchoolRecommendationError: LocalizedError {
  case invalidResponse
  case serverError(Int)

  var errorDescription: String? {
    switch self {
    case .invalidResponse: return "Couldn't reach the server."
    case .serverError(let code): return "Server error (\(code)). Please try again."
    }
  }
}
