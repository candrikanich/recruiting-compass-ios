import Foundation

/// Service contract for coach CRUD operations and associated interaction retrieval.
protocol CoachesManaging: Sendable {
  /// Returns all schools belonging to the given family unit (used to populate school pickers).
  func fetchSchools(familyUnitId: String) async throws -> [School]
  /// Returns all coaches associated with the given school IDs.
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  /// Returns a single coach by ID.
  func fetchCoach(id: String) async throws -> Coach
  /// Creates a new coach record and returns the persisted entity.
  func createCoach(request: CoachCreateRequest) async throws -> Coach
  /// Applies partial updates to a coach and returns the updated entity.
  func updateCoach(id: String, updates: CoachUpdateRequest) async throws -> Coach
  /// Returns the most recent interactions logged with a coach, capped at `limit`.
  func fetchInteractions(coachId: String, limit: Int) async throws -> [Interaction]
  /// Returns the most recent interactions across every coach at a school, capped
  /// at `limit`. Powers the cross-coach ranking on the coach detail screen.
  func fetchInteractions(schoolId: String, limit: Int) async throws -> [Interaction]
  /// Deletes the coach record without cascading to related data.
  func deleteCoach(id: String) async throws
  /// Deletes the coach and all associated interaction records.
  func cascadeDeleteCoach(id: String) async throws -> DeleteResult
}
