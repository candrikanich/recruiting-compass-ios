import Foundation
import Combine
@testable import TheRecruitingCompass

final class MockFamilyService: FamilyManaging, @unchecked Sendable {
  // MARK: - Call Counts

  var fetchFamilyMembersCallCount = 0
  var getCurrentMemberCallCount = 0
  var getFamilyUnitCallCount = 0

  // MARK: - Error Flags

  var shouldThrowFetchMembers = false
  var shouldThrowGetCurrentMember = false
  var shouldThrowGetFamilyUnit = false

  // MARK: - Configurable Return Values

  var stubbedCurrentMember: FamilyMember?
  var stubbedFamilyMembers: [FamilyMember] = []
  var stubbedFamilyUnit: FamilyUnit?

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

  func getFamilyUnit(forPlayerUserId userId: String) async throws -> FamilyUnit? {
    getFamilyUnitCallCount += 1
    if shouldThrowGetFamilyUnit {
      throw NSError(domain: "MockFamily", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock get family unit error"])
    }
    return stubbedFamilyUnit
  }
}

@MainActor
final class MockFamilyManager: ObservableObject {
  @Published var currentMember: FamilyMember?
  @Published var familyMembers: [FamilyMember] = []
  @Published var selectedAthleteId: String?
  @Published var familyUnit: FamilyUnit?

  var familyUnitId: String?

  var isParentViewingAthlete: Bool {
    guard let current = currentMember else { return false }
    return current.isParent && selectedAthleteId != nil
  }

  var selectedAthlete: FamilyMember? {
    guard let athleteId = selectedAthleteId else { return nil }
    return familyMembers.first { $0.id == athleteId }
  }

  var athletes: [FamilyMember] {
    familyMembers.filter { $0.isAthlete }
  }

  init() {}
}
