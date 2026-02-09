import Foundation
@testable import TheRecruitingCompass

final class MockCoachesService: CoachesManaging, @unchecked Sendable {
  // MARK: - Call Counts

  var fetchSchoolsCallCount = 0
  var fetchCoachesCallCount = 0
  var deleteCoachCallCount = 0
  var cascadeDeleteCoachCallCount = 0

  // MARK: - Captured Arguments

  var lastFetchSchoolsFamilyUnitId: String?
  var lastFetchCoachesSchoolIds: [String]?
  var lastDeletedCoachId: String?
  var lastCascadeDeletedCoachId: String?

  // MARK: - Error Flags

  var shouldThrowFetchSchools = false
  var shouldThrowFetchCoaches = false
  var shouldThrowDeleteCoach = false
  var shouldThrowCascadeDelete = false

  // MARK: - Configurable Return Values

  var stubbedSchools: [School] = []
  var stubbedCoaches: [Coach] = []
  var stubbedDeleteResult = DeleteResult(
    isCascadeUsed: true,
    deletedInteractions: 3,
    deletedNotes: 1
  )

  // MARK: - CoachesManaging

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    fetchSchoolsCallCount += 1
    lastFetchSchoolsFamilyUnitId = familyUnitId
    if shouldThrowFetchSchools {
      throw NSError(domain: "MockCoaches", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock fetch schools error"])
    }
    return stubbedSchools
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    fetchCoachesCallCount += 1
    lastFetchCoachesSchoolIds = schoolIds
    if shouldThrowFetchCoaches {
      throw NSError(domain: "MockCoaches", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock fetch coaches error"])
    }
    return stubbedCoaches
  }

  func deleteCoach(id: String) async throws {
    deleteCoachCallCount += 1
    lastDeletedCoachId = id
    if shouldThrowDeleteCoach {
      throw NSError(domain: "MockCoaches", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock delete coach error"])
    }
  }

  func cascadeDeleteCoach(id: String) async throws -> DeleteResult {
    cascadeDeleteCoachCallCount += 1
    lastCascadeDeletedCoachId = id
    if shouldThrowCascadeDelete {
      throw NSError(domain: "MockCoaches", code: 4, userInfo: [NSLocalizedDescriptionKey: "Mock cascade delete error"])
    }
    return stubbedDeleteResult
  }
}
