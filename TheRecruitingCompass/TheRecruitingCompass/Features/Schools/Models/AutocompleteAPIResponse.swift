import Foundation

// MARK: - Autocomplete API Response

struct AutocompleteAPIResponse: Sendable {
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

  enum CodingKeys: String, CodingKey {
    case metadata
    case results
  }
}

extension AutocompleteAPIResponse: Decodable {
  nonisolated init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    metadata = try container.decode(Metadata.self, forKey: .metadata)
    results = try container.decode([AutocompleteResult].self, forKey: .results)
  }
}

extension AutocompleteAPIResponse: Encodable {
  nonisolated func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(metadata, forKey: .metadata)
    try container.encode(results, forKey: .results)
  }
}
