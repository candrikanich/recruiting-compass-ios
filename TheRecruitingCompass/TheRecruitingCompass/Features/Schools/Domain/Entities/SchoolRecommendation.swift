import Foundation

struct SchoolRecommendation: Codable, Identifiable, Sendable {
  let catalogKey: String
  let name: String
  let division: String?
  let conference: String?
  let state: String?
  let score: Double
  let reasons: [String]

  var id: String { catalogKey }

  enum CodingKeys: String, CodingKey {
    case catalogKey = "catalog_key"
    case name, division, conference, state, score, reasons
  }
}
