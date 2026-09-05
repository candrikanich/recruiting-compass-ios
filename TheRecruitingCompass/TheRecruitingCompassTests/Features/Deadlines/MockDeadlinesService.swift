import Foundation
@testable import TheRecruitingCompass

final class MockDeadlinesService: DeadlinesManaging, @unchecked Sendable {
  var deadlines: [Deadline] = []
  var fetchError: Error?
  var createError: Error?
  var deleteError: Error?

  func fetchDeadlines(familyUnitId: String) async throws -> [Deadline] {
    if let fetchError { throw fetchError }
    return deadlines
      .filter { $0.familyUnitId == familyUnitId }
      .sorted { $0.deadlineDate < $1.deadlineDate }
  }

  func createDeadline(_ request: DeadlineCreateRequest) async throws -> Deadline {
    if let createError { throw createError }
    let deadline = Deadline(
      id: UUID().uuidString,
      userId: request.userId,
      familyUnitId: request.familyUnitId,
      label: request.label,
      deadlineDate: request.deadlineDate,
      category: request.category,
      schoolId: request.schoolId,
      createdAt: nil,
      updatedAt: nil
    )
    deadlines.append(deadline)
    return deadline
  }

  func deleteDeadline(id: String, familyUnitId: String) async throws {
    if let deleteError { throw deleteError }
    deadlines.removeAll { $0.id == id && $0.familyUnitId == familyUnitId }
  }
}
