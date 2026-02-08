import Foundation

struct Coach: Codable, Identifiable, Sendable {
  let id: String
  let firstName: String
  let lastName: String
  let email: String?
  let phone: String?
  let position: String?
  let schoolId: String
  let twitterHandle: String?
  let instagramHandle: String?
  let notes: String?
  let responsivenessScore: Double
  let lastContactDate: String?
  let createdAt: String
  let updatedAt: String

  var fullName: String {
    "\(firstName) \(lastName)"
  }

  var initials: String {
    let first = firstName.prefix(1).uppercased()
    let last = lastName.prefix(1).uppercased()
    return "\(first)\(last)"
  }

  var role: CoachRole {
    guard let position else { return .assistant }
    return CoachRole(rawValue: position.lowercased()) ?? .assistant
  }

  var lastContactDateParsed: Date? {
    guard let lastContactDate else { return nil }
    return ISO8601DateFormatter().date(from: lastContactDate)
  }

  enum CodingKeys: String, CodingKey {
    case id
    case firstName = "first_name"
    case lastName = "last_name"
    case email
    case phone
    case position
    case schoolId = "school_id"
    case twitterHandle = "twitter_handle"
    case instagramHandle = "instagram_handle"
    case notes
    case responsivenessScore = "responsiveness_score"
    case lastContactDate = "last_contact_date"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
