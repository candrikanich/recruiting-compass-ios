import Foundation

struct CreateInteractionRequest: Encodable, Sendable {
  let userId: String
  let eventId: String
  let coachId: String?
  let type: String
  let direction: String
  let sentiment: String
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case type, direction, sentiment, notes
    case userId = "user_id"
    case eventId = "event_id"
    case coachId = "coach_id"
  }
}
