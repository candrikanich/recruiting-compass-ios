import Foundation

protocol CoachesManaging: Sendable {
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func createCoach(request: CoachCreateRequest) async throws -> Coach
  func updateCoach(id: String, updates: CoachUpdateRequest) async throws -> Coach
  func fetchInteractions(coachId: String, limit: Int) async throws -> [Interaction]
  func deleteCoach(id: String) async throws
  func cascadeDeleteCoach(id: String) async throws -> DeleteResult
}
