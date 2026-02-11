import Foundation

/// Request model for creating a new coach
struct CoachCreateRequest: Encodable, Sendable {
  let schoolId: String
  let userId: String
  let familyUnitId: String
  let role: String
  let firstName: String
  let lastName: String
  let email: String?
  let phone: String?
  let twitterHandle: String?
  let instagramHandle: String?
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case schoolId = "school_id"
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case role
    case firstName = "first_name"
    case lastName = "last_name"
    case email
    case phone
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case notes
  }
}
