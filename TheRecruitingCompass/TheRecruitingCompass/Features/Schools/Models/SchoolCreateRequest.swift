import Foundation

/// Request model for creating a new school
struct SchoolCreateRequest: Encodable, Sendable {
  let userId: String
  let familyUnitId: String
  let name: String
  let location: String?
  let city: String?
  let state: String?
  let division: String?
  let conference: String?
  let website: String?
  let twitterHandle: String?
  let instagramHandle: String?
  let ncaaId: String?
  let notes: String?
  let status: String
  let academicInfo: AcademicInfo?

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case name
    case location
    case city
    case state
    case division
    case conference
    case website
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case ncaaId = "ncaa_id"
    case notes
    case status
    case academicInfo = "academic_info"
  }
}
