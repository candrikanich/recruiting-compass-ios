import Foundation

// MARK: - API Response Models

struct CollegeScorecardAPIResponse: Codable, Sendable {
  let metadata: Metadata
  let results: [CollegeDataResult]

  struct Metadata: Codable, Sendable {
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

// MARK: - Autocomplete API Response

struct AutocompleteAPIResponse: Codable, Sendable {
  let metadata: Metadata
  let results: [AutocompleteResult]

  struct Metadata: Codable, Sendable {
    let total: Int
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
      case total
      case page
      case perPage = "per_page"
    }
  }

  struct AutocompleteResult: Codable, Sendable {
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
