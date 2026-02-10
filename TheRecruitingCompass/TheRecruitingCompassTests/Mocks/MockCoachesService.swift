import Foundation
@testable import TheRecruitingCompass

final class MockCoachesService: CoachesManaging, @unchecked Sendable {
  // MARK: - Call Counts

  var fetchSchoolsCallCount = 0
  var fetchCoachesCallCount = 0
  var updateCoachCallCount = 0
  var fetchInteractionsCallCount = 0
  var deleteCoachCallCount = 0
  var cascadeDeleteCoachCallCount = 0

  // MARK: - Captured Arguments

  var lastFetchSchoolsFamilyUnitId: String?
  var lastFetchCoachesSchoolIds: [String]?
  var lastUpdateCoachId: String?
  var lastUpdateCoachUpdates: CoachUpdateRequest?
  var lastFetchInteractionsCoachId: String?
  var lastFetchInteractionsLimit: Int?
  var lastDeletedCoachId: String?
  var lastCascadeDeletedCoachId: String?

  // MARK: - Error Flags

  var shouldThrowFetchSchools = false
  var shouldThrowFetchCoaches = false
  var shouldThrowUpdateCoach = false
  var shouldThrowFetchInteractions = false
  var shouldThrowDeleteCoach = false
  var shouldThrowCascadeDelete = false

  // MARK: - Configurable Return Values

  var stubbedSchools: [School] = []
  var stubbedCoaches: [Coach] = []
  var stubbedUpdatedCoach: Coach?
  var stubbedInteractions: [Interaction] = []
  var stubbedDeleteResult = DeleteResult(
    isCascadeUsed: true,
    deletedInteractions: 3,
    deletedNotes: 1
  )

  // Convenience aliases for tests
  var mockCoaches: [Coach] {
    get { stubbedCoaches }
    set { stubbedCoaches = newValue }
  }

  var shouldSucceed: Bool {
    get { !shouldThrowFetchCoaches }
    set { shouldThrowFetchCoaches = !newValue }
  }

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

  func updateCoach(id: String, updates: CoachUpdateRequest) async throws -> Coach {
    updateCoachCallCount += 1
    lastUpdateCoachId = id
    lastUpdateCoachUpdates = updates
    if shouldThrowUpdateCoach {
      throw NSError(domain: "MockCoaches", code: 5, userInfo: [NSLocalizedDescriptionKey: "Mock update coach error"])
    }
    guard let coach = stubbedUpdatedCoach else {
      throw NSError(domain: "MockCoaches", code: 6, userInfo: [NSLocalizedDescriptionKey: "No stubbed coach configured"])
    }
    return coach
  }

  func fetchInteractions(coachId: String, limit: Int) async throws -> [Interaction] {
    fetchInteractionsCallCount += 1
    lastFetchInteractionsCoachId = coachId
    lastFetchInteractionsLimit = limit
    if shouldThrowFetchInteractions {
      throw NSError(domain: "MockCoaches", code: 7, userInfo: [NSLocalizedDescriptionKey: "Mock fetch interactions error"])
    }
    return stubbedInteractions
  }
}
