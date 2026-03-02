import Foundation
import Observation
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
  var lastFamilyIdRegenerated: String?
  var lastMemberIdRemoved: String?
  var lastFamilyCodeJoined: String?
  var lastCreatedFamilyRole: UserRole?

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

  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit? {
    getFamilyUnitCallCount += 1
    lastUserIdFetched = userId

    if !shouldSucceed {
      throw mockError
    }

    return stubbedFamilyUnit
  }

  func createFamily(role: UserRole) async throws -> CreateFamilyResponse {
    createFamilyCallCount += 1
    lastCreatedFamilyRole = role

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

  var sendEmailInviteCallCount = 0
  var revokeInvitationCallCount = 0
  var lookupInviteCallCount = 0
  var acceptInviteCallCount = 0
  var lastInviteEmail: String?
  var lastRevokedInvitationId: String?
  var lastLookedUpToken: String?
  var lastAcceptedToken: String?
  var stubbedPendingInvitations: [FamilyInvitation] = []
  var stubbedInviteDetails = InviteDetails(
    invitationId: "inv-1",
    email: "invited@example.com",
    role: "parent",
    familyName: "Test Family",
    inviterName: "Test Player",
    emailExists: false,
    prefill: nil
  )
  var declineInviteCallCount = 0
  var lastDeclinedToken: String?
  var resendInvitationCallCount = 0
  var lastResendId: String?
  var lastResendEmail: String?
  var lastResendRole: String?

  func sendEmailInvite(email: String, role: String) async throws {
    sendEmailInviteCallCount += 1
    lastInviteEmail = email
    if !shouldSucceed { throw mockError }
  }

  func fetchPendingInvitations() async throws -> [FamilyInvitation] {
    if !shouldSucceed { throw mockError }
    return stubbedPendingInvitations
  }

  func revokeInvitation(id: String) async throws {
    revokeInvitationCallCount += 1
    lastRevokedInvitationId = id
    if !shouldSucceed { throw mockError }
  }

  func lookupInviteByToken(_ token: String) async throws -> InviteDetails {
    lookupInviteCallCount += 1
    lastLookedUpToken = token
    if !shouldSucceed { throw mockError }
    return stubbedInviteDetails
  }

  func acceptInvite(token: String) async throws {
    acceptInviteCallCount += 1
    lastAcceptedToken = token
    if !shouldSucceed { throw mockError }
  }

  func declineInvite(token: String) async throws {
    declineInviteCallCount += 1
    lastDeclinedToken = token
    if !shouldSucceed { throw mockError }
  }

  func resendInvitation(id: String, email: String, role: String) async throws {
    resendInvitationCallCount += 1
    lastResendId = id
    lastResendEmail = email
    lastResendRole = role
    if !shouldSucceed { throw mockError }
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
    lastFamilyIdRegenerated = nil
    lastCreatedFamilyRole = nil
    lastMemberIdRemoved = nil
    lastFamilyCodeJoined = nil

    sendEmailInviteCallCount = 0
    revokeInvitationCallCount = 0
    lookupInviteCallCount = 0
    acceptInviteCallCount = 0
    lastInviteEmail = nil
    lastRevokedInvitationId = nil
    lastLookedUpToken = nil
    lastAcceptedToken = nil
    stubbedPendingInvitations = []
    declineInviteCallCount = 0
    lastDeclinedToken = nil
    resendInvitationCallCount = 0
    lastResendId = nil
    lastResendEmail = nil
    lastResendRole = nil
  }
}

@Observable
@MainActor
final class MockFamilyManager {
  var currentMember: FamilyMember?
  var familyMembers: [FamilyMember] = []
  var selectedAthleteId: String?
  var familyUnit: FamilyUnit?

  var familyUnitId: String? {
    // First try family_members table (works for all users)
    if let familyUnitId = currentMember?.familyUnitId {
      return familyUnitId
    }
    // Fallback to family_units table (for players who might not be in family_members yet)
    return familyUnit?.id
  }

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
