import Foundation

struct DeadlineCreateRequest: Sendable {
  let userId: String
  let familyUnitId: String
  let label: String
  let deadlineDate: String      // "YYYY-MM-DD"
  let category: DeadlineCategory
  let schoolId: String?
}

struct DeadlineUpdateRequest: Sendable {
  let label: String
  let deadlineDate: String      // "YYYY-MM-DD"
  let category: DeadlineCategory
  let schoolId: String?
}

protocol DeadlinesManaging: Sendable {
  func fetchDeadlines(familyUnitId: String) async throws -> [Deadline]
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func createDeadline(_ request: DeadlineCreateRequest) async throws -> Deadline
  func updateDeadline(id: String, familyUnitId: String, request: DeadlineUpdateRequest) async throws -> Deadline
  func deleteDeadline(id: String, familyUnitId: String) async throws
}
