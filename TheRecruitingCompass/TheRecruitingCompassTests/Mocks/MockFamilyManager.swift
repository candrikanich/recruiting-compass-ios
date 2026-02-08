import Foundation
@testable import TheRecruitingCompass

final class MockFamilyService: FamilyManaging, @unchecked Sendable {
  // MARK: - Call Counts

  var fetchFamilyMembersCallCount = 0
  var getCurrentMemberCallCount = 0

  // MARK: - Error Flags

  var shouldThrowFetchMembers = false
  var shouldThrowGetCurrentMember = false

  // MARK: - Configurable Return Values

  var stubbedCurrentMember: FamilyMember?
  var stubbedFamilyMembers: [FamilyMember] = []

  // MARK: - FamilyManaging

  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    fetchFamilyMembersCallCount += 1
    if shouldThrowFetchMembers {
      throw NSError(domain: "MockFamily", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock fetch members error"])
    }
    return stubbedFamilyMembers
  }

  func getCurrentMember(userId: String) async throws -> FamilyMember? {
    getCurrentMemberCallCount += 1
    if shouldThrowGetCurrentMember {
      throw NSError(domain: "MockFamily", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock get current member error"])
    }
    return stubbedCurrentMember
  }
}
