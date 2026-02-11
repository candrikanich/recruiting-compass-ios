import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CollegeScorecardService")

protocol CollegeScorecardManaging: Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult?
  func searchColleges(query: String) async throws -> [CollegeSearchResult]
}

final class CollegeScorecardService: CollegeScorecardManaging, @unchecked Sendable {
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

    // Build URL with query parameters
    var components = URLComponents(string: "https://api.data.gov/ed/collegescorecard/v1/schools")!

    // Fields to request from API
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

    components.queryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "school.name", value: name),
      URLQueryItem(name: "fields", value: fields),
      URLQueryItem(name: "per_page", value: "1")
    ]

    guard let url = components.url else {
      throw CollegeDataError.invalidResponse
    }

    logger.debug("Request URL: \(url.absoluteString)")

    // Make request
    do {
      let (data, response) = try await urlSession.data(from: url)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw CollegeDataError.invalidResponse
      }

      logger.debug("Response status: \(httpResponse.statusCode)")

      switch httpResponse.statusCode {
      case 200:
        // Success - parse response
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(CollegeScorecardAPIResponse.self, from: data)

        guard let firstResult = apiResponse.results.first else {
          logger.info("No results found for: \(name)")
          // Cache nil result to avoid repeated lookups
          await cache.setLookup(for: name, result: nil)
          return nil
        }

        logger.info("Found college: \(firstResult.name)")
        // Cache successful result
        await cache.setLookup(for: name, result: firstResult)
        return firstResult

      case 401, 403:
        throw CollegeDataError.invalidApiKey

      case 429:
        throw CollegeDataError.rateLimited

      case 500...599:
        throw CollegeDataError.serverError(httpResponse.statusCode)

      default:
        throw CollegeDataError.invalidResponse
      }

    } catch let error as CollegeDataError {
      throw error
    } catch {
      logger.error("Network error: \(error.localizedDescription)")
      throw CollegeDataError.networkError(error)
    }
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

    // Build URL with query parameters
    var components = URLComponents(string: "https://api.data.gov/ed/collegescorecard/v1/schools")!

    // Minimal fields for autocomplete
    let fields = [
      "id",
      "school.name",
      "school.city",
      "school.state",
      "school.school_url"
    ].joined(separator: ",")

    components.queryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "school.name", value: query),
      URLQueryItem(name: "fields", value: fields),
      URLQueryItem(name: "per_page", value: "10")
    ]

    guard let url = components.url else {
      throw CollegeDataError.invalidResponse
    }

    logger.debug("Autocomplete URL: \(url.absoluteString)")

    // Make request
    do {
      let (data, response) = try await urlSession.data(from: url)

      guard let httpResponse = response as? HTTPURLResponse else {
        throw CollegeDataError.invalidResponse
      }

      logger.debug("Autocomplete response status: \(httpResponse.statusCode)")

      switch httpResponse.statusCode {
      case 200:
        // Success - parse response
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(AutocompleteAPIResponse.self, from: data)

        let results = apiResponse.results.compactMap { result -> CollegeSearchResult? in
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

        logger.info("Found \(results.count) colleges for query: \(query)")
        // Cache search results
        await cache.setSearch(for: query, results: results)
        return results

      case 401, 403:
        throw CollegeDataError.invalidApiKey

      case 429:
        throw CollegeDataError.rateLimited

      case 500...599:
        throw CollegeDataError.serverError(httpResponse.statusCode)

      default:
        throw CollegeDataError.invalidResponse
      }

    } catch let error as CollegeDataError {
      throw error
    } catch {
      logger.error("Autocomplete network error: \(error.localizedDescription)")
      throw CollegeDataError.networkError(error)
    }
  }
}

// MARK: - API Response Models

private struct CollegeScorecardAPIResponse: Codable {
  let metadata: Metadata
  let results: [CollegeDataResult]

  struct Metadata: Codable {
    let total: Int
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
      case total
      case page
      case perPage = "per_page"
    }
  }
}

// MARK: - Autocomplete API Response (Phase 2)

private struct AutocompleteAPIResponse: Codable {
  let metadata: Metadata
  let results: [AutocompleteResult]

  struct Metadata: Codable {
    let total: Int
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
      case total
      case page
      case perPage = "per_page"
    }
  }

  struct AutocompleteResult: Codable {
    let id: Int?
    let name: String?
    let city: String?
    let state: String?
    let website: String?

    enum CodingKeys: String, CodingKey {
      case id
      case name = "school.name"
      case city = "school.city"
      case state = "school.state"
      case website = "school.school_url"
    }
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
  private let ttl: TimeInterval = 600 // 10 minutes

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
      expiry: Date().addingTimeInterval(ttl)
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
      expiry: Date().addingTimeInterval(ttl)
    )
  }

  func clearExpired() {
    let now = Date()
    lookupCache = lookupCache.filter { $0.value.expiry > now }
    searchCache = searchCache.filter { $0.value.expiry > now }
  }
}
