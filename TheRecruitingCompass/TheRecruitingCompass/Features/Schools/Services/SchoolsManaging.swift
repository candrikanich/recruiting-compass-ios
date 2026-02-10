import Foundation

protocol SchoolsManaging: Sendable {
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchSchool(id: String, familyUnitId: String) async throws -> School
  func deleteSchool(id: String) async throws
  func cascadeDeleteSchool(id: String) async throws -> DeleteResult
  func toggleFavorite(id: String, isFavorite: Bool) async throws
  func updateStatus(
    id: String,
    newStatus: SchoolStatus,
    previousStatus: SchoolStatus,
    userId: String
  ) async throws -> School
  func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory]
}
