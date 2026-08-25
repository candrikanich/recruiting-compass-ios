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
  let tags: [String]
  let source: String?

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
    case tags
    case source
  }

  /// `tags`/`source` default so existing call sites compile unchanged.
  init(
    schoolId: String,
    userId: String,
    familyUnitId: String,
    role: String,
    firstName: String,
    lastName: String,
    email: String? = nil,
    phone: String? = nil,
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    notes: String? = nil,
    tags: [String] = [],
    source: String? = nil
  ) {
    self.schoolId = schoolId
    self.userId = userId
    self.familyUnitId = familyUnitId
    self.role = role
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.phone = phone
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.notes = notes
    self.tags = tags
    self.source = source
  }
}
