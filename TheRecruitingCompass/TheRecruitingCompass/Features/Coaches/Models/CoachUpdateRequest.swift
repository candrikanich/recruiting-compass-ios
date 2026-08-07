import Foundation

struct CoachUpdateRequest: Codable, Sendable {
  let firstName: String?
  let lastName: String?
  let email: String?
  let phone: String?
  let position: String?
  let twitterHandle: String?
  let instagramHandle: String?
  let notes: String?
  let nextContactDate: String?
  let followUpThresholdDays: Int?
  let lastContactDate: String?

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case email, phone, position
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case notes
    case nextContactDate = "next_contact_date"
    case followUpThresholdDays = "follow_up_threshold_days"
    case lastContactDate = "last_contact_date"
  }

  /// All fields default to nil so callers can update a single field (e.g. `CoachUpdateRequest(lastContactDate:)`)
  /// without listing the rest. Only non-nil fields are meaningful to the update.
  init(
    firstName: String? = nil,
    lastName: String? = nil,
    email: String? = nil,
    phone: String? = nil,
    position: String? = nil,
    twitterHandle: String? = nil,
    instagramHandle: String? = nil,
    notes: String? = nil,
    nextContactDate: String? = nil,
    followUpThresholdDays: Int? = nil,
    lastContactDate: String? = nil
  ) {
    self.firstName = firstName
    self.lastName = lastName
    self.email = email
    self.phone = phone
    self.position = position
    self.twitterHandle = twitterHandle
    self.instagramHandle = instagramHandle
    self.notes = notes
    self.nextContactDate = nextContactDate
    self.followUpThresholdDays = followUpThresholdDays
    self.lastContactDate = lastContactDate
  }
}
