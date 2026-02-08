import Foundation

struct Interaction: Codable, Identifiable, Sendable {
  let id: String
  let type: String
  let direction: String
  let notes: String?
  let interactionDate: String?
  let coachId: String?
  let schoolId: String?
  let loggedBy: String
  let createdAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case type
    case direction
    case notes
    case interactionDate = "interaction_date"
    case coachId = "coach_id"
    case schoolId = "school_id"
    case loggedBy = "logged_by"
    case createdAt = "created_at"
  }
}
