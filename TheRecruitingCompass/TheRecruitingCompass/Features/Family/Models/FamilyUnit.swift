import Foundation

/// Parent-entered player info stored on family_units (pending_player_details) or sent with invite.
struct PendingPlayerDetails: Codable, Sendable, Equatable {
  let firstName: String
  let lastName: String
  let sport: String?
  let position: String?
  let graduationYear: Int?

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case sport
    case position
    case graduationYear = "graduation_year"
  }
}

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
  let pendingPlayerDetails: PendingPlayerDetails?

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
    case pendingPlayerDetails = "pending_player_details"
  }
}
