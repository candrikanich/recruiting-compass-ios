import Foundation
@testable import TheRecruitingCompass

final class MockInteractionsService: InteractionsManaging {
  var shouldSucceed = true
  var mockInteractions: [Interaction] = []
  var mockSchools: [School] = []
  var mockCoaches: [Coach] = []
  var deleteCallCount = 0
  var cascadeDeleteCallCount = 0
  var lastDeletedId: String?
  var lastCascadeDeletedId: String?

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockInteractions
  }

  func fetchInteractionsForUser(userId: String) async throws -> [Interaction] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockInteractions.filter { $0.loggedBy == userId }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockSchools
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    return mockCoaches.filter { schoolIds.contains($0.schoolId) }
  }

  func deleteInteraction(id: String) async throws {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    deleteCallCount += 1
    lastDeletedId = id
    mockInteractions.removeAll { $0.id == id }
  }

  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult {
    if !shouldSucceed { throw NSError(domain: "test", code: -1) }
    cascadeDeleteCallCount += 1
    lastCascadeDeletedId = id
    mockInteractions.removeAll { $0.id == id }
    return CascadeDeleteResult(deletedInteractions: 1, deletedNotes: 2)
  }

  func reset() {
    shouldSucceed = true
    mockInteractions = []
    mockSchools = []
    mockCoaches = []
    deleteCallCount = 0
    cascadeDeleteCallCount = 0
    lastDeletedId = nil
    lastCascadeDeletedId = nil
  }
}
