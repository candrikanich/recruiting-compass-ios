import Foundation

protocol FamilyManaging: Sendable {
  // Existing methods
  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember]
  func getCurrentMember(userId: String) async throws -> FamilyMember?
  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit?

  // Family Management methods (Player + Parent)
  func createFamily(role: UserRole) async throws -> CreateFamilyResponse
  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse
  func removeFamilyMember(memberId: String) async throws

  // Family Management methods (Parent)
  func joinFamilyWithCode(familyCode: String) async throws
  func getParentFamilies() async throws -> [ParentFamilyData]

  // Invite operations (email-based)
  func sendEmailInvite(email: String, role: String, pendingPlayerDetails: PendingPlayerDetails?) async throws
  func fetchPendingInvitations() async throws -> [FamilyInvitation]
  func revokeInvitation(id: String) async throws
  func resendInvitation(id: String, email: String, role: String) async throws
  func lookupInviteByToken(_ token: String) async throws -> InviteDetails
  func acceptInvite(token: String) async throws
  func declineInvite(token: String) async throws
  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws
}

