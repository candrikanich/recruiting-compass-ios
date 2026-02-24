import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DashboardService")

/// Sendable: Stateless service with no mutable properties
final class DashboardServiceImpl: DashboardManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  private func fetch<T: Decodable>(
    _ label: String,
    query: () async throws -> [T]
  ) async throws -> [T] {
    logger.debug("Fetching \(label)")
    do {
      let result = try await query()
      logger.info("Fetched \(result.count) \(label)")
      return result
    } catch {
      logger.error("Failed to fetch \(label): \(error.localizedDescription)")
      if let decodingError = error as? DecodingError {
        logger.error("Decoding error: \(String(describing: decodingError))")
      }
      throw error
    }
  }

  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats {
    logger.debug("fetchStats - familyUnitId: \(familyUnitId), userId: \(userId)")

    do {
      async let schools = fetchSchools(familyUnitId: familyUnitId)
      async let offers = fetchOffers(userId: userId)
      async let interactions = fetchInteractions(userId: userId, limit: nil)

      let (schoolList, offerList, interactionList) = try await (schools, offers, interactions)

      let schoolIds = schoolList.map(\.id)
      let coaches = try await fetchCoaches(schoolIds: schoolIds)

      let coachCount = coaches.count
      let schoolCount = schoolList.count
      let interactionCount = interactionList.count
      let totalOffers = offerList.count
      let acceptedOffers = offerList.filter { $0.status == .accepted }.count
      let aTierSchoolCount = schoolList.filter { $0.priorityTier == "A" }.count
      let acceptanceRate = totalOffers > 0 ? Double(acceptedOffers) / Double(totalOffers) : nil

      logger.info("fetchStats SUCCESS - schools: \(schoolCount), coaches: \(coachCount), interactions: \(interactionCount), offers: \(totalOffers)")

      return DashboardStats(
        coachCount: coachCount,
        schoolCount: schoolCount,
        interactionCount: interactionCount,
        totalOffers: totalOffers,
        acceptedOffers: acceptedOffers,
        aTierSchoolCount: aTierSchoolCount,
        acceptanceRate: acceptanceRate
      )
    } catch {
      logger.error("fetchStats FAILED: \(error.localizedDescription)")
      if let decodingError = error as? DecodingError {
        logger.error("Decoding error details: \(String(describing: decodingError))")
      }
      throw error
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await fetch("schools") {
      try await supabaseManager.client
        .from("schools")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .execute()
        .value
    }
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    guard !schoolIds.isEmpty else {
      logger.debug("No school IDs provided, returning empty coaches list")
      return []
    }

    return try await fetch("coaches") {
      try await supabaseManager.client
        .from("coaches")
        .select()
        .in("school_id", values: schoolIds)
        .execute()
        .value
    }
  }

  func fetchInteractions(userId: String, limit: Int?) async throws -> [Interaction] {
    try await fetch("interactions") {
      var query = supabaseManager.client
        .from("interactions")
        .select()
        .eq("logged_by", value: userId)
        .order("created_at", ascending: false)

      if let limit = limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchOffers(userId: String) async throws -> [Offer] {
    try await fetch("offers") {
      try await supabaseManager.client
        .from("offers")
        .select()
        .eq("user_id", value: userId)
        .execute()
        .value
    }
  }

  func fetchEvents(userId: String, limit: Int?) async throws -> [FullEvent] {
    try await fetch("events") {
      var query = supabaseManager.client
        .from("events")
        .select()
        .eq("user_id", value: userId)
        .order("start_date", ascending: true)

      if let limit = limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric] {
    try await fetch("metrics") {
      var query = supabaseManager.client
        .from("performance_metrics")
        .select()
        .eq("user_id", value: userId)
        .order("recorded_date", ascending: false)

      if let limit = limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchSuggestions(location: String, accessToken: String?) async throws -> (suggestions: [Suggestion], pendingCount: Int) {
    guard let baseURL = SupabaseConfig.apiBaseURL,
          let token = accessToken, !token.isEmpty else {
      logger.debug("Suggestions API not configured (API_BASE_URL or token missing), returning empty")
      return ([], 0)
    }

    var components = URLComponents(url: baseURL.appendingPathComponent("api/suggestions"), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "location", value: location)]
    guard let url = components.url else {
      throw NSError(domain: "DashboardService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid suggestions URL"])
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw NSError(domain: "DashboardService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }

    guard http.statusCode == 200 else {
      logger.error("Suggestions API returned \(http.statusCode)")
      throw NSError(domain: "DashboardService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Suggestions failed (\(http.statusCode))"])
    }

    let decoder = JSONDecoder()
    let result = try decoder.decode(SuggestionsResponse.self, from: data)
    logger.info("Fetched \(result.suggestions.count) suggestions, pendingCount: \(result.pendingCount)")
    return (result.suggestions, result.pendingCount)
  }

  func dismissSuggestion(id: String, accessToken: String?) async throws {
    guard let baseURL = SupabaseConfig.apiBaseURL,
          let token = accessToken, !token.isEmpty else {
      logger.debug("Suggestions API not configured, skipping dismiss")
      return
    }

    let csrfToken = try await fetchCSRFToken(baseURL: baseURL)

    let url = baseURL.appendingPathComponent("api/suggestions/\(id)/dismiss")
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw NSError(domain: "DashboardService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    if http.statusCode == 403 {
      throw SuggestionsAPIError.forbidden
    }
    guard http.statusCode == 200 else {
      throw NSError(domain: "DashboardService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Dismiss failed (\(http.statusCode))"])
    }
    logger.info("Suggestion \(id) dismissed")
  }

  func completeSuggestion(id: String, accessToken: String?) async throws {
    guard let baseURL = SupabaseConfig.apiBaseURL,
          let token = accessToken, !token.isEmpty else {
      logger.debug("Suggestions API not configured, skipping complete")
      return
    }

    let csrfToken = try await fetchCSRFToken(baseURL: baseURL)

    let url = baseURL.appendingPathComponent("api/suggestions/\(id)/complete")
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw NSError(domain: "DashboardService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    if http.statusCode == 403 {
      throw SuggestionsAPIError.forbidden
    }
    guard http.statusCode == 200 else {
      throw NSError(domain: "DashboardService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Complete failed (\(http.statusCode))"])
    }
    logger.info("Suggestion \(id) completed")
  }

  /// Fetches CSRF token from API (GET /api/csrf-token). Server sets csrf-token cookie;
  /// we read it and return the value so callers can send it in x-csrf-token header on mutating requests.
  /// URLSession.shared will send the cookie automatically on subsequent requests to the same origin.
  private func fetchCSRFToken(baseURL: URL) async throws -> String {
    let url = baseURL.appendingPathComponent("api/csrf-token")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      logger.error("CSRF token request failed")
      throw NSError(domain: "DashboardService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CSRF token"])
    }

    // Cookie may be scoped to /api; ask for cookies that would be sent to an API path
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrfCookie = cookies.first(where: { $0.name == "csrf-token" }) else {
      logger.error("No csrf-token cookie in storage after GET /api/csrf-token")
      throw NSError(domain: "DashboardService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No CSRF token in response"])
    }

    return csrfCookie.value
  }
}

enum SuggestionsAPIError: Error, LocalizedError {
  case forbidden

  var errorDescription: String? {
    switch self {
    case .forbidden: return "You can't dismiss or complete action items when viewing another athlete's dashboard."
    }
  }
}
