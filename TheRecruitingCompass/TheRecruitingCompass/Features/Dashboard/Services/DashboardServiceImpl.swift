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

  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats {
    logger.debug("fetchStats - familyUnitId: \(familyUnitId), userId: \(userId)")

    do {
      async let schoolIdsTask = fetchSchoolIds(familyUnitId: familyUnitId)
      async let interactionCountTask = exactCount(
        table: "interactions",
        column: "logged_by",
        value: userId
      )
      async let monthCountTask = countInteractionsThisMonth(userId: userId)
      async let upcomingTask = countUpcomingEvents(userId: userId)
      async let offerRowsTask = fetchOfferStatRows(userId: userId)

      let schoolIds = try await schoolIdsTask
      async let coachCountTask = exactCoachCount(schoolIds: schoolIds)

      let interactionCount = try await interactionCountTask
      let interactionsThisMonth = try await monthCountTask
      let upcomingEventCount = try await upcomingTask
      let offerRows = try await offerRowsTask
      let coachCount = try await coachCountTask

      let schoolCount = schoolIds.count
      let totalOffers = offerRows.count
      let acceptedOffers = offerRows.count(where: { $0.status == .accepted })
      let acceptanceRate = totalOffers > 0 ? Double(acceptedOffers) / Double(totalOffers) : nil
      let schoolsWithOffers = Set(offerRows.map(\.schoolId)).count

      logger.info("fetchStats SUCCESS - schools: \(schoolCount), coaches: \(coachCount), interactions: \(interactionCount), upcomingEvents: \(upcomingEventCount), offers: \(totalOffers)")

      return DashboardStats(
        coachCount: coachCount,
        schoolCount: schoolCount,
        interactionCount: interactionCount,
        upcomingEventCount: upcomingEventCount,
        totalOffers: totalOffers,
        acceptedOffers: acceptedOffers,
        acceptanceRate: acceptanceRate,
        schoolsWithOffers: schoolsWithOffers,
        interactionsThisMonth: interactionsThisMonth
      )
    } catch {
      logger.error("fetchStats FAILED: \(error.localizedDescription)")
      if let decodingError = error as? DecodingError {
        logger.error("Decoding error details: \(String(describing: decodingError))")
      }
      throw error
    }
  }

  private struct SchoolIdRow: Decodable, Sendable {
    let id: String
  }

  private struct OfferStatRow: Decodable, Sendable {
    let schoolId: String
    let status: OfferStatus
    enum CodingKeys: String, CodingKey {
      case schoolId = "school_id"
      case status
    }
  }

  private func fetchSchoolIds(familyUnitId: String) async throws -> [String] {
    let rows: [SchoolIdRow] = try await logger.fetch("school ids") {
      try await supabaseManager.client
        .from("schools")
        .select("id")
        .eq("family_unit_id", value: familyUnitId)
        .execute()
        .value
    }
    return rows.map(\.id)
  }

  private func fetchOfferStatRows(userId: String) async throws -> [OfferStatRow] {
    try await logger.fetch("offer stats") {
      try await supabaseManager.client
        .from("offers")
        .select("school_id, status")
        .eq("user_id", value: userId)
        .execute()
        .value
    }
  }

  private func exactCount(table: String, column: String, value: String) async throws -> Int {
    do {
      let response = try await supabaseManager.client
        .from(table)
        .select("id", head: true, count: .exact)
        .eq(column, value: value)
        .execute()
      logger.debug("exactCount(\(table)) = \(response.count ?? 0)")
      return response.count ?? 0
    } catch {
      logger.error("exactCount(\(table)) FAILED: \(error.localizedDescription)")
      throw error
    }
  }

  private func exactCoachCount(schoolIds: [String]) async throws -> Int {
    guard !schoolIds.isEmpty else { return 0 }
    do {
      let response = try await supabaseManager.client
        .from("coaches")
        .select("id", head: true, count: .exact)
        .in("school_id", values: schoolIds)
        .execute()
      logger.debug("exactCoachCount = \(response.count ?? 0)")
      return response.count ?? 0
    } catch {
      logger.error("exactCoachCount FAILED: \(error.localizedDescription)")
      throw error
    }
  }

  private func countUpcomingEvents(userId: String) async throws -> Int {
    do {
      let response = try await supabaseManager.client
        .from("events")
        .select("id", head: true, count: .exact)
        .eq("user_id", value: userId)
        .gte("start_date", value: Self.todayPrefix())
        .execute()
      logger.debug("countUpcomingEvents = \(response.count ?? 0)")
      return response.count ?? 0
    } catch {
      logger.error("countUpcomingEvents FAILED: \(error.localizedDescription)")
      throw error
    }
  }

  /// Counts interactions in the current calendar month using date range filters.
  /// Uses `gte`/`lt` on timestamptz columns (PostgREST `like` only works on text).
  private func countInteractionsThisMonth(userId: String) async throws -> Int {
    let (monthStart, nextMonthStart) = Self.currentMonthRange()
    do {
      async let withOccurred: Int = {
        let response = try await supabaseManager.client
          .from("interactions")
          .select("id", head: true, count: .exact)
          .eq("logged_by", value: userId)
          .gte("occurred_at", value: monthStart)
          .lt("occurred_at", value: nextMonthStart)
          .execute()
        return response.count ?? 0
      }()
      async let withoutOccurred: Int = {
        let response = try await supabaseManager.client
          .from("interactions")
          .select("id", head: true, count: .exact)
          .eq("logged_by", value: userId)
          .is("occurred_at", value: nil)
          .gte("created_at", value: monthStart)
          .lt("created_at", value: nextMonthStart)
          .execute()
        return response.count ?? 0
      }()
      let total = try await withOccurred + withoutOccurred
      logger.debug("countInteractionsThisMonth = \(total)")
      return total
    } catch {
      logger.error("countInteractionsThisMonth FAILED: \(error.localizedDescription)")
      throw error
    }
  }

  /// Returns (firstDayOfMonth, firstDayOfNextMonth) as ISO8601 strings for range queries.
  private static func currentMonthRange(now: Date = .now) -> (start: String, end: String) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let components = calendar.dateComponents([.year, .month], from: now)
    let monthStart = calendar.date(from: components)!
    let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart)!
    let formatter = ISO8601DateFormatter()
    return (formatter.string(from: monthStart), formatter.string(from: nextMonthStart))
  }

  /// "yyyy-MM-dd" for today (device local day), matched lexicographically against
  /// event `startDate` strings — mirrors the Events list's "Upcoming" cutoff.
  private static func todayPrefix(now: Date = .now) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: now)
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await logger.fetch("schools") {
      try await FamilyScopedQueries.fetchSchools(from: supabaseManager.client, familyUnitId: familyUnitId)
    }
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    guard !schoolIds.isEmpty else {
      logger.debug("No school IDs provided, returning empty coaches list")
      return []
    }

    return try await logger.fetch("coaches") {
      try await supabaseManager.client
        .from("coaches")
        .select()
        .in("school_id", values: schoolIds)
        .execute()
        .value
    }
  }

  func fetchInteractions(userId: String, limit: Int?) async throws -> [Interaction] {
    try await logger.fetch("interactions") {
      var query = supabaseManager.client
        .from("interactions")
        .select()
        .eq("logged_by", value: userId)
        .order("created_at", ascending: false)

      if let limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchOffers(userId: String) async throws -> [Offer] {
    try await logger.fetch("offers") {
      try await supabaseManager.client
        .from("offers")
        .select()
        .eq("user_id", value: userId)
        .execute()
        .value
    }
  }

  func fetchEvents(userId: String, limit: Int?) async throws -> [FullEvent] {
    try await logger.fetch("events") {
      var query = supabaseManager.client
        .from("events")
        .select()
        .eq("user_id", value: userId)
        .order("start_date", ascending: true)

      if let limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric] {
    try await logger.fetch("metrics") {
      var query = supabaseManager.client
        .from("performance_metrics")
        .select()
        .eq("user_id", value: userId)
        .order("recorded_date", ascending: false)

      if let limit {
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

    guard var components = URLComponents(url: baseURL.appendingPathComponent("api/suggestions"), resolvingAgainstBaseURL: false) else {
      throw SuggestionsAPIError.notConfigured
    }
    components.queryItems = [URLQueryItem(name: "location", value: location)]
    guard let url = components.url else {
      throw SuggestionsAPIError.notConfigured
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    // API expects JWT access token only; refresh_token would 401 (supabase.auth.getUser(accessToken))

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw SuggestionsAPIError.invalidResponse
    }

    guard http.statusCode == 200 else {
      logger.error("Suggestions API returned \(http.statusCode)")
      if http.statusCode == 401 {
        throw SuggestionsAPIError.unauthorized
      }
      throw SuggestionsAPIError.serverError(http.statusCode)
    }

    // Empty response (e.g. HTML error page, empty body) often causes "data is missing" decode error
    guard !data.isEmpty else {
      logger.debug("Suggestions API returned empty body, treating as no suggestions")
      return ([], 0)
    }

    do {
      let decoder = JSONDecoder()
      let result = try decoder.decode(SuggestionsResponse.self, from: data)
      logger.info("Fetched \(result.suggestions.count) suggestions, pendingCount: \(result.pendingCount)")
      return (result.suggestions, result.pendingCount)
    } catch let error as DecodingError {
      logger.warning("Suggestions API response decode failed: \(String(describing: error)). Treating as empty.")
      return ([], 0)
    } catch {
      throw error
    }
  }

  func dismissSuggestion(id: String, accessToken: String?) async throws {
    guard let baseURL = SupabaseConfig.apiBaseURL,
          let token = accessToken, !token.isEmpty else {
      logger.debug("Suggestions API not configured, skipping dismiss")
      return
    }

    let csrfToken = try await fetchCSRFToken(baseURL: baseURL)

    let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    let url = baseURL
      .appendingPathComponent("api/suggestions")
      .appendingPathComponent(safeId)
      .appendingPathComponent("dismiss")
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw SuggestionsAPIError.invalidResponse
    }
    if http.statusCode == 403 {
      throw SuggestionsAPIError.forbidden
    }
    guard http.statusCode == 200 else {
      throw SuggestionsAPIError.serverError(http.statusCode)
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

    let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    let url = baseURL
      .appendingPathComponent("api/suggestions")
      .appendingPathComponent(safeId)
      .appendingPathComponent("complete")
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw SuggestionsAPIError.invalidResponse
    }
    if http.statusCode == 403 {
      throw SuggestionsAPIError.forbidden
    }
    guard http.statusCode == 200 else {
      throw SuggestionsAPIError.serverError(http.statusCode)
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
      throw SuggestionsAPIError.csrfFailed
    }

    // Cookie may be scoped to /api; ask for cookies that would be sent to an API path
    let apiURL = baseURL.appendingPathComponent("api")
    guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
          let csrfCookie = cookies.first(where: { $0.name == "csrf-token" }) else {
      logger.error("No csrf-token cookie in storage after GET /api/csrf-token")
      throw SuggestionsAPIError.csrfFailed
    }

    return csrfCookie.value
  }
}
