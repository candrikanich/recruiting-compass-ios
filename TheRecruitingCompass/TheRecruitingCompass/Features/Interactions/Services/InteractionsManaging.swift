import Foundation

/// Service contract for interaction CRUD operations, attachment uploads, and cascade deletion.
///
/// Interactions record contacts with coaches (calls, emails, campus visits, etc.)
/// and may include file attachments stored in Supabase Storage.
protocol InteractionsManaging: Sendable {
  // List operations
  /// Returns all interactions belonging to the family unit, across all coaches.
  func fetchInteractions(familyUnitId: String) async throws -> [Interaction]
  /// Returns interactions logged by a specific user.
  func fetchInteractionsForUser(userId: String) async throws -> [Interaction]

  // Detail operations
  /// Returns a single interaction by ID.
  func fetchInteraction(id: String) async throws -> Interaction
  /// Returns the display name of the user who logged a given interaction.
  func fetchLoggedByUserName(userId: String) async throws -> String

  // Form data operations
  /// Returns all schools for the family unit (used to populate school pickers in the form).
  func fetchSchools(familyUnitId: String) async throws -> [School]
  /// Returns all coaches for the family unit (used to populate coach pickers in the form).
  func fetchCoaches(familyUnitId: String) async throws -> [Coach]

  // Create/Update operations
  /// Creates a new interaction record and returns the persisted entity.
  func createInteraction(_ interaction: InteractionCreateRequest) async throws -> Interaction
  /// Creates a coach inline from the interaction form and returns the new coach.
  func createCoach(_ coach: CoachCreateRequest) async throws -> Coach
  /// Uploads a file attachment to Supabase Storage and returns the resulting public URL.
  func uploadAttachment(interactionId: String, fileName: String, fileData: Data) async throws -> String

  // Delete operations
  /// Deletes the interaction record without cascading.
  func deleteInteraction(id: String) async throws
  /// Deletes the interaction and all associated notes, returning counts of removed records.
  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult
}

/// Counts of records removed during a cascade interaction delete.
struct CascadeDeleteResult: Codable, Sendable {
  /// Number of interaction records deleted.
  let deletedInteractions: Int
  /// Number of note records deleted.
  let deletedNotes: Int

  enum CodingKeys: String, CodingKey {
    case deletedInteractions = "deleted_interactions"
    case deletedNotes = "deleted_notes"
  }
}
