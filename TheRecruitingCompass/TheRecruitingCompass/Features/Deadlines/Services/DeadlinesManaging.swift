import Foundation

struct DeadlineCreateRequest: Sendable {
  let userId: String
  let familyUnitId: String
  let label: String
  let deadlineDate: String      // "YYYY-MM-DD"
  let category: DeadlineCategory
  let schoolId: String?
}

protocol DeadlinesManaging: Sendable {
  func fetchDeadlines(familyUnitId: String) async throws -> [Deadline]
  func createDeadline(_ request: DeadlineCreateRequest) async throws -> Deadline
  func deleteDeadline(id: String, familyUnitId: String) async throws
}
