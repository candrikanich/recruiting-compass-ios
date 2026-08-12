import Foundation

/// Service contract for family unit management, member operations, and email-based invitations.
protocol FamilyManaging: Sendable {
  // Existing methods
  /// Returns all members belonging to the given family unit.
  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember]
  /// Returns the `FamilyMember` record for the currently authenticated user, or `nil` if not in a family.
  func getCurrentMember(userId: String) async throws -> FamilyMember?
  /// Returns the `FamilyUnit` the given user belongs to, or `nil` if they have not joined one.
  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit?

  // Family Management methods (Player + Parent)
  /// Creates a new family unit for the current user and returns a response containing the join code.
  func createFamily(role: UserRole) async throws -> CreateFamilyResponse
  /// Rotates the family join code and returns the updated code.
  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse
  /// Removes the specified member from the family unit.
  func removeFamilyMember(memberId: String) async throws

  // Family Management methods (Parent)
  /// Adds the current user to an existing family using the given join code.
  func joinFamilyWithCode(familyCode: String) async throws
  /// Returns all family units the current parent user is associated with.
  func getParentFamilies() async throws -> [ParentFamilyData]

  // Invite operations (email-based)
  /// Sends an email invitation to join the family unit with the specified role.
  /// - Parameter pendingPlayerDetails: Pre-filled player profile data to attach to the invite, if applicable.
  func sendEmailInvite(email: String, role: String, pendingPlayerDetails: PendingPlayerDetails?) async throws
  /// Returns all pending (unsettled) email invitations for the current family.
  func fetchPendingInvitations() async throws -> [FamilyInvitation]
  /// Cancels a pending invitation so it can no longer be accepted.
  func revokeInvitation(id: String) async throws
  /// Re-sends the invitation email for an existing pending invite.
  func resendInvitation(id: String, email: String, role: String) async throws
  /// Looks up invite details by the token embedded in a deep-link URL.
  func lookupInviteByToken(_ token: String) async throws -> InviteDetails
  /// Accepts a family invitation, adding the current user to the family.
  func acceptInvite(token: String) async throws
  /// Declines a family invitation without joining.
  func declineInvite(token: String) async throws
  /// Saves pending player profile details to the family record before the player creates their account.
  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws
}
