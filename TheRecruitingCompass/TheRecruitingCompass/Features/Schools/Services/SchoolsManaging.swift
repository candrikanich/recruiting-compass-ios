import Foundation

protocol SchoolsManaging: Sendable {
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func deleteSchool(id: String) async throws
  func cascadeDeleteSchool(id: String) async throws -> DeleteResult
  func toggleFavorite(id: String, isFavorite: Bool) async throws
}
