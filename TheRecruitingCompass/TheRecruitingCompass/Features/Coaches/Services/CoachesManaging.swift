import Foundation

protocol CoachesManaging: Sendable {
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func deleteCoach(id: String) async throws
  func cascadeDeleteCoach(id: String) async throws -> DeleteResult
}
