import Foundation

struct DeleteResult: Codable, Sendable {
  let isCascadeUsed: Bool
  let deletedInteractions: Int
  let deletedNotes: Int

  enum CodingKeys: String, CodingKey {
    case isCascadeUsed = "cascade_used"
    case deletedInteractions = "deleted_interactions"
    case deletedNotes = "deleted_notes"
  }
}
