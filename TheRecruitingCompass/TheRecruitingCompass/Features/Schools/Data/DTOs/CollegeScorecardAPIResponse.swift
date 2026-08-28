import Foundation

struct CollegeScorecardAPIResponse: Sendable {
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

  enum CodingKeys: String, CodingKey {
    case metadata
    case results
  }
}

extension CollegeScorecardAPIResponse: Decodable {
  nonisolated init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    metadata = try container.decode(Metadata.self, forKey: .metadata)
    results = try container.decode([CollegeDataResult].self, forKey: .results)
  }
}

extension CollegeScorecardAPIResponse: Encodable {
  nonisolated func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(metadata, forKey: .metadata)
    try container.encode(results, forKey: .results)
  }
}
