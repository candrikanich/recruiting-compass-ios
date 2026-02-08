import Foundation

struct Activity: Codable, Identifiable, Sendable {
  let id: String
  let activityType: String
  let description: String
  let timestamp: String
  let userId: String
  let relatedEntityId: String?

  enum CodingKeys: String, CodingKey {
    case id
    case activityType = "activity_type"
    case description
    case timestamp
    case userId = "user_id"
    case relatedEntityId = "related_entity_id"
  }
}
