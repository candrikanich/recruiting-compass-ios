import Foundation

struct Event: Codable, Identifiable, Sendable {
  let id: String
  let title: String
  let description: String?
  let eventDate: String
  let eventType: String
  let location: String?
  let schoolId: String?
  let userId: String
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case description
    case eventDate = "event_date"
    case eventType = "event_type"
    case location
    case schoolId = "school_id"
    case userId = "user_id"
    case createdAt = "created_at"
  }
}
