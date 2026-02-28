import Foundation

struct FamilyUnit: Codable, Identifiable, Sendable {
  let id: String
  let createdByUserId: String
  let familyName: String?
  let familyCode: String?
  let codeGeneratedAt: String?
  let createdAt: String?
  let updatedAt: String?
  let homeLatitude: Double?
  let homeLongitude: Double?

  enum CodingKeys: String, CodingKey {
    case id
    case createdByUserId = "created_by_user_id"
    case familyName = "family_name"
    case familyCode = "family_code"
    case codeGeneratedAt = "code_generated_at"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case homeLatitude = "home_latitude"
    case homeLongitude = "home_longitude"
  }
}
