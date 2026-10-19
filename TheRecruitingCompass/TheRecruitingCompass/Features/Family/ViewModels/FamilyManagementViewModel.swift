import Observation
import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyManagementViewModel")

@Observable
@MainActor
final class FamilyManagementViewModel {

  nonisolated deinit {}
  // MARK: - Player State
  var familyCode: String?
  var familyId: String?
  var familyName: String?
  var codeGeneratedAt: String?
  /// The family has no code and generating one failed — show a retry, not a spinner.
  var familyCodeUnavailable = false
  var familyMembers: [FamilyMember] = []
  var pendingInvitations: [FamilyInvitation] = []
  var inviteEmail: String = ""

  // MARK: - Parent State
  var parentFamilies: [ParentFamilyData] = []
  var codeInput: String = ""

  // MARK: - Inbound Email State
  var inboundAddresses: [InboundFamilyAddress] = []

  // MARK: - Shared State
  var isLoading = false
  var loadingMembers = false
  var errorMessage: String?
  var successMessage: String?
  var showSuccessToast = false
  var showDeleteConfirmation = false
  var memberToRemove: FamilyMember?
  var showRegenerateConfirmation = false

  // MARK: - Leave State (parents)
  var familyToLeave: ParentFamilyData?
  var showLeaveConfirmation = false
  /// The server's own warning text once it has asked for confirmation to delete an emptied family.
  var lastMemberLeaveWarning: String?
  var showLastMemberConfirmation = false

  // MARK: - Dependencies
  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging
  private let inboundDraftsService: any InboundDraftsAPIManaging
  private static let isoFormatter = ISO8601DateFormatter()

  /// Called after a leave so app-wide family context (FamilyManager) drops the family and its cached rows.
  var onMembershipChanged: (@MainActor () async -> Void)?

  private var accessToken: String? { authManager.session?.accessToken }

  // MARK: - Computed Properties
  var isPlayer: Bool {
    authManager.user?.role == .player
  }

  var isParent: Bool {
    authManager.user?.role == .parent
  }

  var isCodeInputValid: Bool {
    let trimmed = codeInput.trimmingCharacters(in: .whitespaces)
    return trimmed.range(of: FamilyConstants.Validation.codePattern, options: .regularExpression) != nil
  }

  var isEmailInviteValid: Bool {
    let trimmed = inviteEmail.trimmingCharacters(in: .whitespaces)
    return trimmed.contains("@") && trimmed.contains(".")
  }

  var formattedCodeGeneratedAt: String? {
    guard let timestamp = codeGeneratedAt else { return nil }
    return DateFormatter.familyCodeDate.string(from: Self.isoFormatter.date(from: timestamp) ?? Date.now)
  }

  // MARK: - Initialization
  init(
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    inboundDraftsService: (any InboundDraftsAPIManaging)? = nil
  ) {
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.inboundDraftsService = inboundDraftsService ?? InboundDraftsAPIService()
  }

  // MARK: - Load Data
  func loadData() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    if isPlayer {
      await loadPlayerData()
    } else if isParent {
      await loadParentData()
    }
    await loadInboundAddress()
  }

  private func loadInboundAddress() async {
    do {
      inboundAddresses = try await inboundDraftsService.fetchForwardingAddress(accessToken: accessToken)
    } catch {
      // Non-critical display — a fetch failure here must never break the page —
      // but log at error level so recurring outages are still visible in telemetry.
      logger.error("Failed to load inbound address: \(error.localizedDescription)")
    }
  }

  /// Families are read straight from Supabase (no label there), so labels come from the inbound-address endpoint,
  /// which returns the server's `familyLabel` for every family the user belongs to.
  func displayLabel(for family: ParentFamilyData) -> String {
    inboundAddresses.first { $0.familyUnitId == family.familyId }?.displayLabel ?? family.familyName
  }

  /// Heading for the player's family code card. Only a server `familyLabel` changes it: the stored name is
  /// usually the generic "My Family", which must not replace "Your Family Code" on API versions without labels.
  var playerFamilyCodeHeading: String {
    let label = inboundAddresses.first { $0.familyUnitId == familyId }?.familyLabel
    return FamilyLabel.codeHeading(forServerLabel: label)
  }

  func copyInboundAddressToClipboard(_ address: String) {
    UIPasteboard.general.string = address
    showSuccess("Address copied to clipboard!")
  }

  // MARK: - Player Actions
  private func loadPlayerData() async {
    guard let userId = authManager.user?.id else {
      errorMessage = "User not authenticated"
      return
    }

    do {
      // Fetch or create family unit
      if let familyUnit = try await familyService.getFamilyUnit(forUserId: userId) {
        familyCode = familyUnit.familyCode
        familyId = familyUnit.id
        familyName = familyUnit.familyName
        codeGeneratedAt = familyUnit.codeGeneratedAt
        if familyCode == nil {
          await generateMissingFamilyCode(familyId: familyUnit.id)
        }

        // Load family members and pending invitations
        await loadFamilyMembers(familyUnitId: familyUnit.id)
        await loadPendingInvitations()
      } else {
        // No family unit exists, create one
        await createFamily()
      }
    } catch {
      logger.error("Failed to load player data: \(error.localizedDescription)")
      errorMessage = "Failed to load family data. Please try again."
    }
  }

  /// Some families were created without a code (seeded / legacy rows). Generate one rather than
  /// leaving the code card spinning forever.
  private func generateMissingFamilyCode(familyId: String) async {
    do {
      let response = try await familyService.regenerateCode(familyId: familyId)
      familyCode = response.familyCode
      codeGeneratedAt = Self.isoFormatter.string(from: Date.now)
      familyCodeUnavailable = false
    } catch {
      logger.error("Failed to generate missing family code: \(error.localizedDescription)")
      familyCodeUnavailable = true
    }
  }

  func retryMissingFamilyCode() async {
    guard let familyId else { return }
    familyCodeUnavailable = false
    await generateMissingFamilyCode(familyId: familyId)
  }

  private func loadFamilyMembers(familyUnitId: String) async {
    loadingMembers = true
    defer { loadingMembers = false }

    do {
      familyMembers = try await fetchDetail(familyUnitId: familyUnitId).members
    } catch {
      logger.error("Failed to load family members: \(error.localizedDescription)")
      errorMessage = "Failed to load family members"
    }
  }

  private func fetchDetail(familyUnitId: String) async throws -> FamilyMembersDetail {
    try await Self.fetchDetail(familyUnitId: familyUnitId, via: familyService)
  }

  /// The web API carries the server's removal/leave verdicts. If it is unreachable the direct read keeps the list
  /// visible, with every rule field nil — which the UI treats as "no Remove, no Leave", never as allowed.
  nonisolated private static func fetchDetail(
    familyUnitId: String, via service: any FamilyManaging
  ) async throws -> FamilyMembersDetail {
    do {
      return try await service.fetchFamilyDetail(familyUnitId: familyUnitId)
    } catch {
      logger.error("Family detail unavailable, using direct read: \(error.localizedDescription)")
      return FamilyMembersDetail(members: try await service.fetchFamilyMembers(familyUnitId: familyUnitId))
    }
  }

  func createFamily() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let role = isPlayer ? UserRole.player : UserRole.parent
      let response = try await familyService.createFamily(role: role)
      familyCode = response.familyCode
      familyId = response.familyId
      familyName = response.familyName
      codeGeneratedAt = Self.isoFormatter.string(from: Date.now)
      familyMembers = []

      showSuccess("Family created successfully!")
    } catch let error as FamilyError {
      logger.error("Failed to create family: \(error.localizedDescription)")
      errorMessage = error.errorDescription ?? "Failed to create family. Please try again."
    } catch {
      logger.error("Failed to create family: \(error.localizedDescription)")
      errorMessage = "Failed to create family. Please try again."
    }
  }

  func copyCodeToClipboard() {
    guard let code = familyCode else { return }
    UIPasteboard.general.string = code
    showSuccess("Family code copied to clipboard!")
  }

  func confirmRegenerateCode() {
    showRegenerateConfirmation = true
  }

  func regenerateCode() async {
    guard let familyId = familyId else {
      errorMessage = "No family ID available"
      return
    }

    isLoading = true
    errorMessage = nil
    showRegenerateConfirmation = false
    defer { isLoading = false }

    do {
      let response = try await familyService.regenerateCode(familyId: familyId)
      familyCode = response.familyCode
      codeGeneratedAt = Self.isoFormatter.string(from: Date.now)

      showSuccess("Family code regenerated successfully!")
    } catch {
      logger.error("Failed to regenerate code: \(error.localizedDescription)")
      errorMessage = error.localizedDescription
    }
  }

  func confirmRemoveMember(_ member: FamilyMember) {
    memberToRemove = member
    showDeleteConfirmation = true
  }

  func removeMember() async {
    guard let member = memberToRemove else { return }

    isLoading = true
    errorMessage = nil
    showDeleteConfirmation = false
    defer { isLoading = false }

    do {
      try await familyService.removeFamilyMember(memberId: member.id)

      // Remove from local state
      familyMembers.removeAll { $0.id == member.id }
      memberToRemove = nil

      showSuccess("Family member removed successfully!")
      await refreshMembers(inFamily: member.familyUnitId)
    } catch {
      logger.error("Failed to remove member: \(error.localizedDescription)")
      errorMessage = error.localizedDescription
      memberToRemove = nil
      // A busy-retry or a stale verdict: re-read so the buttons match what the server now says.
      await refreshMembers(inFamily: member.familyUnitId)
    }
  }

  /// Re-reads one family's members and rule verdicts after a change, so no stale Remove/Leave stays enabled.
  private func refreshMembers(inFamily familyUnitId: String) async {
    if familyId == familyUnitId {
      await loadFamilyMembers(familyUnitId: familyUnitId)
    } else if let index = parentFamilies.firstIndex(where: { $0.familyId == familyUnitId }),
              let detail = try? await fetchDetail(familyUnitId: familyUnitId) {
      parentFamilies[index].members = detail.members
      parentFamilies[index].canLeave = detail.canLeave
      parentFamilies[index].leaveBlockedReason = detail.leaveBlockedReason
    }
  }

  // MARK: - Leave (parents)
  func confirmLeave(_ family: ParentFamilyData) {
    familyToLeave = family
    showLeaveConfirmation = true
  }

  func leaveFamily(confirmDeleteFamily: Bool = false) async {
    guard let family = familyToLeave else { return }
    isLoading = true
    errorMessage = nil
    showLeaveConfirmation = false
    showLastMemberConfirmation = false
    defer { isLoading = false }

    do {
      let outcome = try await familyService.leaveFamily(
        familyId: family.familyId, confirmDeleteFamily: confirmDeleteFamily
      )
      familyToLeave = nil
      parentFamilies.removeAll { $0.familyId == family.familyId }
      inboundAddresses.removeAll { $0.familyUnitId == family.familyId }
      await onMembershipChanged?()
      showSuccess(outcome == .familyDeleted ? "Family deleted." : "You left the family.")
    } catch FamilyError.lastMemberConfirmationRequired(let warning) {
      lastMemberLeaveWarning = warning
      showLastMemberConfirmation = true
    } catch {
      logger.error("Failed to leave family: \(error.localizedDescription)")
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Failed to leave the family. Please try again."
      familyToLeave = nil
      await refreshMembers(inFamily: family.familyId)
    }
  }

  func cancelLeave() {
    familyToLeave = nil
    showLeaveConfirmation = false
    showLastMemberConfirmation = false
  }

  // MARK: - Parent Actions
  private func loadParentData() async {
    do {
      parentFamilies = try await familyService.getParentFamilies()

      // If parent has no family, create one (symmetric: parents can create families)
      if parentFamilies.isEmpty {
        await createFamily()
        parentFamilies = try await familyService.getParentFamilies()
      }
      parentFamilies = await withMembersLoaded(parentFamilies)
      await loadPendingInvitations()
    } catch {
      logger.error("Failed to load parent families: \(error.localizedDescription)")
      errorMessage = "Failed to load families. Please try again."
    }
  }

  private func withMembersLoaded(_ families: [ParentFamilyData]) async -> [ParentFamilyData] {
    var updated = families
    var anyFailed = false

    await withTaskGroup(of: (Int, Result<FamilyMembersDetail, Error>).self) { group in
      for (index, family) in updated.enumerated() {
        group.addTask { [familyService] in
          do {
            return (index, .success(try await Self.fetchDetail(familyUnitId: family.familyId, via: familyService)))
          } catch {
            return (index, .failure(error))
          }
        }
      }

      for await (index, result) in group {
        switch result {
        case .success(let detail):
          updated[index].members = detail.members
          updated[index].canLeave = detail.canLeave
          updated[index].leaveBlockedReason = detail.leaveBlockedReason
        case .failure(let error):
          anyFailed = true
          logger.error("Failed to load members for family \(updated[index].familyId): \(error.localizedDescription)")
        }
      }
    }

    if anyFailed {
      errorMessage = "Some family member lists couldn't be loaded. Please try again."
    }
    return updated
  }

  func joinFamily() async {
    let code = codeInput.trimmingCharacters(in: .whitespaces).uppercased()

    guard isCodeInputValid else {
      errorMessage = "Invalid family code format. Codes look like FAM-XXXXXX"
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let response = try await familyService.joinFamilyWithCode(familyCode: code)

      // Reload parent families, then the inbound addresses that carry their server-resolved labels
      await loadParentData()
      await loadInboundAddress()

      // Clear input
      codeInput = ""

      showSuccess(response?.displayLabel.map { "Successfully joined \($0)!" } ?? "Successfully joined family!")
    } catch let error as FamilyError {
      errorMessage = error.errorDescription
    } catch {
      logger.error("Failed to join family: \(error.localizedDescription)")
      errorMessage = "Failed to join family. Please try again."
    }
  }

  // MARK: - Invite Actions

  private func loadPendingInvitations() async {
    do {
      pendingInvitations = try await familyService.fetchPendingInvitations()
    } catch {
      // intentionally silent: secondary section on an already-loaded family
      // management screen; an empty list here just means none are pending.
      logger.debug("Failed to load pending invitations: \(error.localizedDescription)")
      pendingInvitations = []
    }
  }

  func sendEmailInvite() async {
    guard isEmailInviteValid else {
      errorMessage = "Please enter a valid email address"
      return
    }

    let email = inviteEmail.trimmingCharacters(in: .whitespaces)
    let inviteRole = isPlayer ? "parent" : "player"

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await familyService.sendEmailInvite(email: email, role: inviteRole, pendingPlayerDetails: nil)
      inviteEmail = ""
      await loadPendingInvitations()
      showSuccess("Invite sent to \(email)!")
    } catch {
      logger.error("Failed to send invite: \(error.localizedDescription)")
      errorMessage = (error as? FamilyError)?.errorDescription ?? "Failed to send invite. Please try again."
    }
  }

  func revokeInvitation(_ invitation: FamilyInvitation) async {
    isLoading = true
    defer { isLoading = false }

    do {
      try await familyService.revokeInvitation(id: invitation.id)
      pendingInvitations.removeAll { $0.id == invitation.id }
      showSuccess("Invite revoked.")
    } catch {
      errorMessage = "Failed to revoke invite. Please try again."
    }
  }

  func resendInvitation(_ invitation: FamilyInvitation) async {
    let email = invitation.invitedEmail
    let role = invitation.role

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await familyService.resendInvitation(id: invitation.id, email: email, role: role)
      await loadPendingInvitations()
      showSuccess("Invite resent to \(email)")
    } catch {
      logger.error("Failed to resend invite: \(error.localizedDescription)")
      errorMessage = "Failed to resend invite. Please try again."
    }
  }

  // MARK: - Helpers
  private func showSuccess(_ message: String) {
    successMessage = message
    showSuccessToast = true

    Task {
      try? await Task.sleep(for: FamilyConstants.Duration.successToast)
      showSuccessToast = false
      successMessage = nil
    }
  }

  func formatCodeInput() {
    codeInput = codeInput.uppercased()
  }

  func clearError() {
    errorMessage = nil
  }

}
