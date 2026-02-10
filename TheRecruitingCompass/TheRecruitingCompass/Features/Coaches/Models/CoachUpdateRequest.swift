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
  let privateNotes: [String: String]?

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case email, phone, position
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case notes
    case privateNotes = "private_notes"
  }
}
