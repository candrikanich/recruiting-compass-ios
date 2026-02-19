import Foundation
import OSLog

nonisolated private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CollegeScorecardService")

protocol CollegeScorecardManaging: Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult?
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
      // TODO: Replace with actual API key from secure storage
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
    logger.debug("Request URL: \(url.absoluteString)")

    // Perform API request
    let apiResponse: CollegeScorecardAPIResponse = try await self.performAPIRequest(url: url)

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
    logger.debug("Autocomplete URL: \(url.absoluteString)")

    // Perform API request
    let apiResponse: AutocompleteAPIResponse = try await self.performAPIRequest(url: url)

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

  func getLookup(for name: String) -> CollegeDataResult?? {
    guard let entry = lookupCache[name.lowercased()], entry.expiry > Date() else {
      lookupCache.removeValue(forKey: name.lowercased())
      return nil
    }
    return entry.value
  }

  func setLookup(for name: String, result: CollegeDataResult?) {
    lookupCache[name.lowercased()] = CachedEntry(
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

  /// Build URL for college lookup request
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
      "latest.admissions.admission_rate.overall",
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
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "school.name", value: query),
      URLQueryItem(name: "fields", value: fields),
      URLQueryItem(name: "per_page", value: perPage)
    ]

    guard let url = components.url else {
      throw CollegeDataError.invalidResponse
    }

    return url
  }

  /// Perform API request and decode response
  private func performAPIRequest<T: Decodable>(url: URL) async throws -> T {
    do {
      let (data, response) = try await urlSession.data(from: url)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw CollegeDataError.invalidResponse
      }

      logger.debug("Response status: \(httpResponse.statusCode)")

      // Check for error status codes
      try validateHTTPStatusCode(httpResponse.statusCode)

      // Decode success response (MainActor hop for types with MainActor-isolated Decodable)
      let decoder = JSONDecoder()
      return try await MainActor.run { try decoder.decode(T.self, from: data) }

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
