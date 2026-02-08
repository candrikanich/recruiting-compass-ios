import Foundation

struct School: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let location: String?
  let tier: String?
  let division: String?
  let conference: String?
  let familyUnitId: String
  let createdAt: String
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case location
    case tier
    case division
    case conference
    case familyUnitId = "family_unit_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
