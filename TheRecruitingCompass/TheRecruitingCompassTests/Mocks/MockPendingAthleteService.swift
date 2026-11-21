import Foundation
@testable import TheRecruitingCompass

final class MockPendingAthleteService: PendingAthleteManaging, @unchecked Sendable {
  var pendingByFamily: [String: PendingAthlete?] = [:]
  var catalog: [TaskRow] = []
  var pendingError: Error?
  var catalogError: Error?
  /// Awaited before a pending read answers, so a test can hold one family's request in flight.
  var pendingGate: (@Sendable (String) async -> Void)?

  private(set) var requestedFamilyIds: [String] = []
  private(set) var requestedCatalogGrades: [Int] = []

  func fetchPendingAthlete(familyUnitId: String) async throws -> PendingAthlete? {
    requestedFamilyIds.append(familyUnitId)
    await pendingGate?(familyUnitId)
    if let pendingError { throw pendingError }
    return pendingByFamily[familyUnitId].flatMap { $0 }
  }

  func fetchTaskCatalog(gradeLevel: Int) async throws -> [TaskRow] {
    requestedCatalogGrades.append(gradeLevel)
    if let catalogError { throw catalogError }
    return catalog
  }
}

extension TaskRow {
  static func stub(
    id: String, grade: Int = 11, category: String = "academic", required: Bool = true,
    why: String? = "Because it matters.", dependencies: [String]? = nil
  ) -> TaskRow {
    TaskRow(
      id: id, title: "Task \(id)", description: nil, gradeLevel: grade, category: category, division: nil,
      required: required, deadlineOffsetMonths: nil, whyItMatters: why, failureRisk: nil,
      dependencyTaskIds: dependencies
    )
  }
}
