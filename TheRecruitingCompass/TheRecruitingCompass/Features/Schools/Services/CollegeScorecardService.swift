import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CollegeScorecardService"
)

protocol CollegeScorecardManaging: Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult?
  func lookupCollege(id: String) async throws -> CollegeDataResult?
  func searchColleges(query: String) async throws -> [CollegeSearchResult]
}

/// Routes College Scorecard requests through the web app proxy at /api/colleges/search.
/// Auth: Supabase session Bearer token. Falls back to CollegeDataError.apiKeyMissing when
/// API_BASE_URL or session token is unavailable.
typealias TokenProvider = @Sendable () async throws -> String?

actor CollegeScorecardService: CollegeScorecardManaging {
  private let urlSession: URLSession
  private let cache = CollegeScorecardCache()
  // Captured at init to avoid crossing actor isolation when reading the MainActor-isolated property.
  private let baseURL: URL?
  private let tokenProvider: TokenProvider

  nonisolated static let defaultTokenProvider: TokenProvider = {
    try? await SupabaseManager.shared.client.auth.session.accessToken
  }

  init(
    urlSession: URLSession = .shared,
    baseURL: URL? = SupabaseConfig.apiBaseURL,
    tokenProvider: @escaping TokenProvider = CollegeScorecardService.defaultTokenProvider
  ) {
    self.urlSession = urlSession
    self.baseURL = baseURL
    self.tokenProvider = tokenProvider
  }

  // MARK: - Public API

  func searchColleges(query: String) async throws -> [CollegeSearchResult] {
    guard query.count >= 3 else { throw CollegeDataError.nameTooShort }

    if let cached = await cache.getSearch(for: query) {
      logger.debug("Cache hit for search: \(query)")
      return cached
    }

    logger.debug("Searching colleges via proxy: \(query)")

    let fields = [
      "id", "school.name", "school.city", "school.state", "school.school_url"
    ].joined(separator: ",")

    let url = try buildURL(queryItems: [
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "fields", value: fields),
      URLQueryItem(name: "per_page", value: "10")
    ])

    let data = try await fetchData(from: url)
    let response = try JSONDecoder().decode(AutocompleteAPIResponse.self, from: data)
    let results = transformAutocompleteResults(response.results)

    logger.info("Found \(results.count) colleges for query: \(query)")
    await cache.setSearch(for: query, results: results)
    return results
  }

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    guard name.count >= 3 else { throw CollegeDataError.nameTooShort }

    let cacheKey = name.lowercased()
    if let cached = await cache.getLookup(for: cacheKey) {
      logger.debug("Cache hit for lookup: \(name)")
      return cached
    }

    logger.debug("Looking up college via proxy: \(name)")

    let url = try buildURL(queryItems: [
      URLQueryItem(name: "q", value: name),
      URLQueryItem(name: "fields", value: detailFields),
      URLQueryItem(name: "per_page", value: "1")
    ])

    let data = try await fetchData(from: url)
    let response = try JSONDecoder().decode(CollegeScorecardAPIResponse.self, from: data)
    let result = response.results.first

    if let result { logger.info("Found college: \(result.name)") }
    else { logger.info("No results for: \(name)") }
    await cache.setLookup(for: cacheKey, result: result)
    return result
  }

  func lookupCollege(id: String) async throws -> CollegeDataResult? {
    let cacheKey = "id:\(id)"
    if let cached = await cache.getLookup(for: cacheKey) {
      logger.debug("Cache hit for lookup id: \(id)")
      return cached
    }

    logger.debug("Looking up college by id via proxy: \(id)")

    let url = try buildURL(queryItems: [
      URLQueryItem(name: "id", value: id),
      URLQueryItem(name: "fields", value: detailFields)
    ])

    let data = try await fetchData(from: url)
    let response = try JSONDecoder().decode(CollegeScorecardAPIResponse.self, from: data)
    let result = response.results.first

    if let result { logger.info("Found college: \(result.name)") }
    else { logger.info("No results for id: \(id)") }
    await cache.setLookup(for: cacheKey, result: result)
    return result
  }

  // MARK: - Private Helpers

  private let detailFields = [
    "id", "school.name", "school.school_url", "school.address",
    "school.city", "school.state", "latest.student.size",
    "school.carnegie_size_setting", "enrollment.all",
    "latest.admissions.admission_rate.overall",
    "latest.student.student_faculty_ratio",
    "latest.cost.tuition.in_state", "latest.cost.tuition.out_of_state",
    "latest.cost.avg_net_price.overall",
    "latest.completion.completion_rate_4yr_150nt",
    "location.lat", "location.lon"
  ].joined(separator: ",")

  private func buildURL(queryItems: [URLQueryItem]) throws -> URL {
    guard let base = baseURL else {
      throw CollegeDataError.apiKeyMissing
    }
    guard var components = URLComponents(
      url: base.appendingPathComponent("api/colleges/search"),
      resolvingAgainstBaseURL: false
    ) else {
      throw CollegeDataError.invalidResponse
    }
    components.queryItems = queryItems
    guard let url = components.url else { throw CollegeDataError.invalidResponse }
    return url
  }

  private func fetchData(from url: URL) async throws -> Data {
    guard let token = try? await tokenProvider(), !token.isEmpty else {
      throw CollegeDataError.sessionMissing
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    do {
      let (data, response) = try await urlSession.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        throw CollegeDataError.invalidResponse
      }
      logger.debug("Proxy response status: \(http.statusCode)")
      try validateStatus(http.statusCode)
      return data
    } catch let error as CollegeDataError {
      throw error
    } catch {
      logger.error("Network error: \(error.localizedDescription)")
      throw CollegeDataError.networkError(error)
    }
  }

  private func validateStatus(_ code: Int) throws {
    switch code {
    case 200: return
    case 401, 403: throw CollegeDataError.invalidApiKey
    case 429: throw CollegeDataError.rateLimited
    case 500...599: throw CollegeDataError.serverError(code)
    default: throw CollegeDataError.invalidResponse
    }
  }

  private func transformAutocompleteResults(
    _ results: [AutocompleteAPIResponse.AutocompleteResult]
  ) -> [CollegeSearchResult] {
    results.compactMap { r -> CollegeSearchResult? in
      guard let id = r.id, let name = r.name,
            let city = r.city, let state = r.state else { return nil }
      return CollegeSearchResult(
        id: String(id), name: name, city: city, state: state, website: r.website
      )
    }
  }
}

// MARK: - Cache

private actor CollegeScorecardCache {
  private struct Entry<T> { let value: T; let expiry: Date }
  private var lookupCache: [String: Entry<CollegeDataResult?>] = [:]
  private var searchCache: [String: Entry<[CollegeSearchResult]>] = [:]
  private let ttl: TimeInterval = 600

  func getLookup(for key: String) -> CollegeDataResult?? {
    guard let e = lookupCache[key], e.expiry > Date() else {
      lookupCache.removeValue(forKey: key); return nil
    }
    return e.value
  }

  func setLookup(for key: String, result: CollegeDataResult?) {
    lookupCache[key] = Entry(value: result, expiry: Date().addingTimeInterval(ttl))
  }

  func getSearch(for query: String) -> [CollegeSearchResult]? {
    let key = query.lowercased()
    guard let e = searchCache[key], e.expiry > Date() else {
      searchCache.removeValue(forKey: key); return nil
    }
    return e.value
  }

  func setSearch(for query: String, results: [CollegeSearchResult]) {
    searchCache[query.lowercased()] = Entry(value: results, expiry: Date().addingTimeInterval(ttl))
  }
}
