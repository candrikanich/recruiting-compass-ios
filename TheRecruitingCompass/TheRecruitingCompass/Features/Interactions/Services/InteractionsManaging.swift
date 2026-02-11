import Foundation

protocol InteractionsManaging: Sendable {
  // List operations
  func fetchInteractions(familyUnitId: String) async throws -> [Interaction]
  func fetchInteractionsForUser(userId: String) async throws -> [Interaction]

  // Detail operations
  func fetchInteraction(id: String) async throws -> Interaction
  func fetchLoggedByUserName(userId: String) async throws -> String

  // Form data operations
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(familyUnitId: String) async throws -> [Coach]

  // Create/Update operations
  func createInteraction(_ interaction: InteractionCreateRequest) async throws -> Interaction
  func createCoach(_ coach: CoachCreateRequest) async throws -> Coach
  func uploadAttachment(interactionId: String, fileName: String, fileData: Data) async throws -> String

  // Delete operations
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
