import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CollegeScorecardService")

protocol CollegeScorecardManaging: Sendable {
  func lookupCollege(name: String) async throws -> CollegeDataResult?
}

final class CollegeScorecardService: CollegeScorecardManaging, @unchecked Sendable {
  private let apiKey: String

  init(apiKey: String? = nil) {
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
  }

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    guard !apiKey.isEmpty else {
      throw CollegeDataError.apiKeyMissing
    }

    guard name.count >= 3 else {
      throw CollegeDataError.nameTooShort
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
      let (data, response) = try await URLSession.shared.data(from: url)

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
          return nil
        }

        logger.info("Found college: \(firstResult.name)")
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
}

// MARK: - API Response Model

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
