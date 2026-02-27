import Foundation
import OSLog

nonisolated private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CollegeScorecardService")

protocol CollegeScorecardManaging: Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult?
  func lookupCollege(id: String) async throws -> CollegeDataResult?
  func searchColleges(query: String) async throws -> [CollegeSearchResult]
}

actor CollegeScorecardService: CollegeScorecardManaging {
  private let apiKey: String
  private let urlSession: URLSession
  private let cache = CollegeScorecardCache()

  init(apiKey: String? = nil, urlSession: URLSession = .shared) {
    // Try to get API key from environment or use placeholder
    if let key = apiKey {
      self.apiKey = key
    } else if let envKey = ProcessInfo.processInfo.environment["COLLEGE_SCORECARD_API_KEY"] {
      self.apiKey = envKey
    } else {
      // Set COLLEGE_SCORECARD_API_KEY in Scheme → Run → Environment Variables, or inject via init, for production.
      self.apiKey = ""
      logger.warning("College Scorecard API key not configured")
    }
    self.urlSession = urlSession
  }

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    guard !apiKey.isEmpty else {
      throw CollegeDataError.apiKeyMissing
    }

    guard name.count >= 3 else {
      throw CollegeDataError.nameTooShort
    }

    // Check cache first
    if let cached = await cache.getLookup(for: name) {
      logger.debug("Cache hit for lookup: \(name)")
      return cached
    }

    logger.debug("Looking up college: \(name)")

    // Build request URL
    let url = try self.buildLookupURL(for: name)

    // Perform API request
    let data = try await self.fetchData(from: url)
    let apiResponse = try JSONDecoder().decode(CollegeScorecardAPIResponse.self, from: data)

    // Extract first result
    guard let firstResult = apiResponse.results.first else {
      logger.info("No results found for: \(name)")
      await cache.setLookup(for: name, result: nil)
      return nil
    }

    // Cache and return result
    logger.info("Found college: \(firstResult.name)")
    await cache.setLookup(for: name, result: firstResult)
    return firstResult
  }

  /// Look up college by College Scorecard ID (IPEDS unit ID) for exact match
  /// Use when autocomplete selection provides ID to avoid wrong matches (e.g. Ohio U vs Ohio State)
  func lookupCollege(id: String) async throws -> CollegeDataResult? {
    guard !apiKey.isEmpty else {
      throw CollegeDataError.apiKeyMissing
    }

    let cacheKey = "id:\(id)"
    if let cached = await cache.getLookup(for: cacheKey) {
      logger.debug("Cache hit for lookup id: \(id)")
      return cached
    }

    logger.debug("Looking up college by id: \(id)")

    let url = try buildLookupURLById(id: id)
    let data = try await fetchData(from: url)
    let apiResponse = try JSONDecoder().decode(CollegeScorecardAPIResponse.self, from: data)

    guard let firstResult = apiResponse.results.first else {
      logger.info("No results found for id: \(id)")
      await cache.setLookup(for: cacheKey, result: nil)
      return nil
    }

    logger.info("Found college: \(firstResult.name)")
    await cache.setLookup(for: cacheKey, result: firstResult)
    return firstResult
  }

  // MARK: - Autocomplete Search (Phase 2)

  /// Search colleges for autocomplete dropdown
  /// - Parameter query: Search query (minimum 3 characters)
  /// - Returns: Array of college search results (max 10)
  func searchColleges(query: String) async throws -> [CollegeSearchResult] {
    guard !apiKey.isEmpty else {
      throw CollegeDataError.apiKeyMissing
    }

    guard query.count >= 3 else {
      throw CollegeDataError.nameTooShort
    }

    // Check cache first
    if let cached = await cache.getSearch(for: query) {
      logger.debug("Cache hit for search: \(query)")
      return cached
    }

    logger.debug("Searching colleges: \(query)")

    // Build request URL
    let url = try self.buildSearchURL(for: query)

    // Perform API request
    let data = try await self.fetchData(from: url)
    let apiResponse = try JSONDecoder().decode(AutocompleteAPIResponse.self, from: data)

    // Transform results
    let results = self.transformAutocompleteResults(apiResponse.results)

    // Cache and return results
    logger.info("Found \(results.count) colleges for query: \(query)")
    await cache.setSearch(for: query, results: results)
    return results
  }
}

// MARK: - Cache Implementation

/// Thread-safe cache for College Scorecard API responses with TTL
private actor CollegeScorecardCache {
  private struct CachedEntry<T> {
    let value: T
    let expiry: Date
  }

  private var lookupCache: [String: CachedEntry<CollegeDataResult?>] = [:]
  private var searchCache: [String: CachedEntry<[CollegeSearchResult]>] = [:]
  private let cacheTimeToLive: TimeInterval = 600 // 10 minutes

  func getLookup(for key: String) -> CollegeDataResult?? {
    let normalized = key.hasPrefix("id:") ? key : key.lowercased()
    guard let entry = lookupCache[normalized], entry.expiry > Date() else {
      lookupCache.removeValue(forKey: normalized)
      return nil
    }
    return entry.value
  }

  func setLookup(for key: String, result: CollegeDataResult?) {
    let normalized = key.hasPrefix("id:") ? key : key.lowercased()
    lookupCache[normalized] = CachedEntry(
      value: result,
      expiry: Date().addingTimeInterval(cacheTimeToLive)
    )
  }

  func getSearch(for query: String) -> [CollegeSearchResult]? {
    guard let entry = searchCache[query.lowercased()], entry.expiry > Date() else {
      searchCache.removeValue(forKey: query.lowercased())
      return nil
    }
    return entry.value
  }

  func setSearch(for query: String, results: [CollegeSearchResult]) {
    searchCache[query.lowercased()] = CachedEntry(
      value: results,
      expiry: Date().addingTimeInterval(cacheTimeToLive)
    )
  }

  func clearExpired() {
    let now = Date()
    lookupCache = lookupCache.filter { $0.value.expiry > now }
    searchCache = searchCache.filter { $0.value.expiry > now }
  }
}

// MARK: - CollegeScorecardService Private Helpers

extension CollegeScorecardService {

  /// Build URL for college lookup by ID (exact match)
  private func buildLookupURLById(id: String) throws -> URL {
    let fields = [
      "id",
      "school.name",
      "school.school_url",
      "school.address",
      "school.city",
      "school.state",
      "latest.student.size",
      "school.carnegie_size_setting",
      "enrollment.all",
      "latest.admissions.admission_rate.overall",
      "latest.student.student_faculty_ratio",
      "latest.cost.tuition.in_state",
      "latest.cost.tuition.out_of_state",
      "location.lat",
      "location.lon"
    ].joined(separator: ",")

    var components = URLComponents(string: "https://api.data.gov/ed/collegescorecard/v1/schools")!
    components.queryItems = [
      URLQueryItem(name: "id", value: id),
      URLQueryItem(name: "fields", value: fields),
      URLQueryItem(name: "per_page", value: "1")
    ]

    guard let url = components.url else {
      throw CollegeDataError.invalidResponse
    }
    return url
  }

  /// Build URL for college lookup by name (text search, may return wrong match)
  private func buildLookupURL(for name: String) throws -> URL {
    let fields = [
      "id",
      "school.name",
      "school.school_url",
      "school.address",
      "school.city",
      "school.state",
      "latest.student.size",
      "school.carnegie_size_setting",
      "enrollment.all",
      "latest.admissions.admission_rate.overall",
      "latest.student.student_faculty_ratio",
      "latest.cost.tuition.in_state",
      "latest.cost.tuition.out_of_state",
      "location.lat",
      "location.lon"
    ].joined(separator: ",")

    return try buildAPIURL(
      query: name,
      fields: fields,
      perPage: "1"
    )
  }

  /// Build URL for college search request
  private func buildSearchURL(for query: String) throws -> URL {
    let fields = [
      "id",
      "school.name",
      "school.city",
      "school.state",
      "school.school_url"
    ].joined(separator: ",")

    return try buildAPIURL(
      query: query,
      fields: fields,
      perPage: "10"
    )
  }

  /// Build API URL with query parameters
  private func buildAPIURL(
    query: String,
    fields: String,
    perPage: String
  ) throws -> URL {
    var components = URLComponents(string: "https://api.data.gov/ed/collegescorecard/v1/schools")!

    components.queryItems = [
      URLQueryItem(name: "school.name", value: query),
      URLQueryItem(name: "fields", value: fields),
      URLQueryItem(name: "per_page", value: perPage)
    ]

    guard let url = components.url else {
      throw CollegeDataError.invalidResponse
    }

    return url
  }

  /// Fetch raw data from URL
  private func fetchData(from url: URL) async throws -> Data {
    do {
      var request = URLRequest(url: url)
      request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
      let (data, response) = try await urlSession.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw CollegeDataError.invalidResponse
      }

      logger.debug("Response status: \(httpResponse.statusCode)")

      try validateHTTPStatusCode(httpResponse.statusCode)
      return data

    } catch let error as CollegeDataError {
      throw error
    } catch {
      logger.error("Network error: \(error.localizedDescription)")
      throw CollegeDataError.networkError(error)
    }
  }

  /// Validate HTTP status code and throw appropriate error
  private func validateHTTPStatusCode(_ statusCode: Int) throws {
    switch statusCode {
    case 200:
      return // Success
    case 401, 403:
      throw CollegeDataError.invalidApiKey
    case 429:
      throw CollegeDataError.rateLimited
    case 500...599:
      throw CollegeDataError.serverError(statusCode)
    default:
      throw CollegeDataError.invalidResponse
    }
  }

  /// Transform autocomplete API results to domain models
  private func transformAutocompleteResults(
    _ results: [AutocompleteAPIResponse.AutocompleteResult]
  ) -> [CollegeSearchResult] {
    results.compactMap { result -> CollegeSearchResult? in
      guard let id = result.id,
            let name = result.name,
            let city = result.city,
            let state = result.state else {
        return nil
      }

      return CollegeSearchResult(
        id: String(id),
        name: name,
        city: city,
        state: state,
        website: result.website
      )
    }
  }
}
