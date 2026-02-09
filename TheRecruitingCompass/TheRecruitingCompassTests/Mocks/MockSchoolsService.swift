import Foundation
@testable import TheRecruitingCompass

final class MockSchoolsService: SchoolsManaging, @unchecked Sendable {
  var fetchSchoolsCallCount = 0
  var deleteSchoolCallCount = 0
  var cascadeDeleteSchoolCallCount = 0
  var toggleFavoriteCallCount = 0

  var stubbedSchools: [School] = []
  var shouldThrowError = false
  var errorToThrow: Error = NSError(domain: "MockSchoolsService", code: -1)

  var stubbedDeleteResult = DeleteResult(isCascadeUsed: true, deletedInteractions: 2, deletedNotes: 1)

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    fetchSchoolsCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedSchools
  }

  func deleteSchool(id: String) async throws {
    deleteSchoolCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
  }

  func cascadeDeleteSchool(id: String) async throws -> DeleteResult {
    cascadeDeleteSchoolCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedDeleteResult
  }

  func toggleFavorite(id: String, isFavorite: Bool) async throws {
    toggleFavoriteCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
  }
}
