import Foundation

protocol InteractionsManaging: Sendable {
  func fetchInteractions(familyUnitId: String) async throws -> [Interaction]
  func fetchInteractionsForUser(userId: String) async throws -> [Interaction]
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func deleteInteraction(id: String) async throws
  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult
}

struct CascadeDeleteResult: Codable, Sendable {
  let deletedInteractions: Int
  let deletedNotes: Int

  enum CodingKeys: String, CodingKey {
    case deletedInteractions = "deleted_interactions"
    case deletedNotes = "deleted_notes"
  }
}
