import Foundation
import Combine
@testable import TheRecruitingCompass

final class MockFamilyService: FamilyManaging, @unchecked Sendable {
  // MARK: - Mock State

  var shouldSucceed = true
  var mockError: Error = FamilyError.serverError("Mock error")

  // MARK: - Call Counts

  var fetchFamilyMembersCallCount = 0
  var getCurrentMemberCallCount = 0
  var getFamilyUnitCallCount = 0
  var createFamilyCallCount = 0
  var regenerateCodeCallCount = 0
  var removeFamilyMemberCallCount = 0
  var joinFamilyWithCodeCallCount = 0
  var getParentFamiliesCallCount = 0

  // MARK: - Configurable Return Values

  var stubbedCurrentMember: FamilyMember?
  var stubbedFamilyMembers: [FamilyMember] = []
  var stubbedFamilyUnit: FamilyUnit?
  var mockCreateFamilyResponse = CreateFamilyResponse(
    success: true,
    familyCode: "FAM-ABC123",
    familyId: "family-1",
    familyName: "Test Family"
  )
  var mockRegenerateCodeResponse = RegenerateFamilyCodeResponse(
    familyCode: "FAM-XYZ789"
  )
  var mockParentFamilies: [ParentFamilyData] = []

  // MARK: - Captured Parameters

  var lastFamilyUnitIdFetched: String?
  var lastUserIdFetched: String?
  var lastPlayerUserIdFetched: String?
  var lastFamilyIdRegenerated: String?
  var lastMemberIdRemoved: String?
  var lastFamilyCodeJoined: String?

  // MARK: - FamilyManaging Implementation

  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    fetchFamilyMembersCallCount += 1
    lastFamilyUnitIdFetched = familyUnitId

    if !shouldSucceed {
      throw mockError
    }

    return stubbedFamilyMembers
  }

  func getCurrentMember(userId: String) async throws -> FamilyMember? {
    getCurrentMemberCallCount += 1
    lastUserIdFetched = userId

    if !shouldSucceed {
      throw mockError
    }

    return stubbedCurrentMember
  }

  func getFamilyUnit(forPlayerUserId userId: String) async throws -> FamilyUnit? {
    getFamilyUnitCallCount += 1
    lastPlayerUserIdFetched = userId

    if !shouldSucceed {
      throw mockError
    }

    return stubbedFamilyUnit
  }

  func createFamily() async throws -> CreateFamilyResponse {
    createFamilyCallCount += 1

    if !shouldSucceed {
      throw mockError
    }

    return mockCreateFamilyResponse
  }

  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse {
    regenerateCodeCallCount += 1
    lastFamilyIdRegenerated = familyId

    if !shouldSucceed {
      throw mockError
    }

    return mockRegenerateCodeResponse
  }

  func removeFamilyMember(memberId: String) async throws {
    removeFamilyMemberCallCount += 1
    lastMemberIdRemoved = memberId

    if !shouldSucceed {
      throw mockError
    }
  }

  func joinFamilyWithCode(familyCode: String) async throws {
    joinFamilyWithCodeCallCount += 1
    lastFamilyCodeJoined = familyCode

    if !shouldSucceed {
      throw mockError
    }
  }

  func getParentFamilies() async throws -> [ParentFamilyData] {
    getParentFamiliesCallCount += 1

    if !shouldSucceed {
      throw mockError
    }

    return mockParentFamilies
  }

  // MARK: - Helper Methods

  func reset() {
    shouldSucceed = true
    mockError = FamilyError.serverError("Mock error")

    fetchFamilyMembersCallCount = 0
    getCurrentMemberCallCount = 0
    getFamilyUnitCallCount = 0
    createFamilyCallCount = 0
    regenerateCodeCallCount = 0
    removeFamilyMemberCallCount = 0
    joinFamilyWithCodeCallCount = 0
    getParentFamiliesCallCount = 0

    stubbedFamilyMembers = []
    stubbedCurrentMember = nil
    stubbedFamilyUnit = nil
    mockCreateFamilyResponse = CreateFamilyResponse(
      success: true,
      familyCode: "FAM-ABC123",
      familyId: "family-1",
      familyName: "Test Family"
    )
    mockRegenerateCodeResponse = RegenerateFamilyCodeResponse(
      familyCode: "FAM-XYZ789"
    )
    mockParentFamilies = []

    lastFamilyUnitIdFetched = nil
    lastUserIdFetched = nil
    lastPlayerUserIdFetched = nil
    lastFamilyIdRegenerated = nil
    lastMemberIdRemoved = nil
    lastFamilyCodeJoined = nil
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
