import Foundation

protocol SchoolsManaging: Sendable {
  // MARK: - Phase 1 Methods
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

  // MARK: - Phase 2 Methods (Editing & Notes)
  func updateNotes(id: String, notes: String) async throws -> School
  func updatePrivateNotes(id: String, familyUnitId: String, userId: String, note: String?) async throws -> School
  func addPro(id: String, familyUnitId: String, text: String) async throws -> School
  func removePro(id: String, familyUnitId: String, index: Int) async throws -> School
  func addCon(id: String, familyUnitId: String, text: String) async throws -> School
  func removeCon(id: String, familyUnitId: String, index: Int) async throws -> School
  func updateBasicInfo(id: String, info: EditableBasicInfo) async throws -> School

  // MARK: - Phase 3 Methods (College Data)
  func mergeCollegeData(id: String, data: CollegeDataResult) async throws -> School

  // MARK: - Phase 4 Methods (Coaching Philosophy)
  func updateCoachingPhilosophy(id: String, philosophy: EditableCoachingPhilosophy) async throws -> School
}
