import Foundation
import OSLog
import SwiftUI
import Observation

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyManager")

@Observable
@MainActor
final class FamilyManager {
  nonisolated deinit {}
  static let shared = FamilyManager()

  var currentMember: FamilyMember?
  var familyMembers: [FamilyMember] = []
  var selectedAthleteId: String?
  var familyUnit: FamilyUnit?

  /// The load currently in flight and the user it is loading for. Concurrent callers for the
  /// same user await it instead of returning early with whatever state is already here.
  private var inFlightLoad: (userId: String, task: Task<Void, Never>)?
  private let familyService: any FamilyManaging
  private let authManager: any AuthManaging

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

  var familyUnitId: String? {
    // First try family_members table (works for all users)
    if let familyUnitId = currentMember?.familyUnitId {
      return familyUnitId
    }
    // Fallback to family_units table (for players who might not be in family_members yet)
    return familyUnit?.id
  }

  init(
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  func loadFamilyData() async {
    guard let userId = authManager.user?.id else { return }
    if let inFlight = inFlightLoad, inFlight.userId == userId {
      await inFlight.task.value
      return
    }
    let task = Task { await performLoad(userId: userId) }
    inFlightLoad = (userId, task)
    await task.value
    if inFlightLoad?.userId == userId {
      inFlightLoad = nil
    }
  }

  private func performLoad(userId: String) async {
    do {
      // Try to get family member record (works for all family members)
      let member = try await familyService.getCurrentMember(userId: userId)
      guard isStillSignedIn(userId) else { return }
      currentMember = member

      // Also fetch family unit via membership (works for all roles)
      let unit = try await familyService.getFamilyUnit(forUserId: userId)
      guard isStillSignedIn(userId) else { return }
      familyUnit = unit
      logger.debug("Fetched family unit: \(self.familyUnit?.id ?? "none")")

      // Mirrors web: no auto-create. User creates family from Family tab when inviting parent.
      if let familyUnitId = self.familyUnitId {
        let members = try await familyService.fetchFamilyMembers(familyUnitId: familyUnitId)
        guard isStillSignedIn(userId) else { return }
        familyMembers = members

        if currentMember?.isAthlete == true {
          selectedAthleteId = currentMember?.id
        } else if currentMember?.isParent == true, selectedAthleteId == nil {
          // Mirror web: a parent auto-views an athlete. Web sorts by closest
          // graduation year; that field isn't loaded here, so default to the
          // first linked athlete (deterministic for single-athlete families).
          selectedAthleteId = familyMembers.first { $0.isAthlete }?.id
        }
      } else {
        logger.warning("No family unit ID found for user \(userId)")
      }
    } catch {
      logger.error("Failed to load family data: \(error.localizedDescription)")
    }
  }

  func selectAthlete(_ athleteId: String?) {
    selectedAthleteId = athleteId
  }

  func clearAthleteSelection() {
    selectedAthleteId = nil
  }

  /// Clears everything tied to the signed-in user. Call when the user signs out or changes;
  /// otherwise the next account starts on the previous account's family and athlete.
  func reset() {
    inFlightLoad = nil
    currentMember = nil
    familyMembers = []
    selectedAthleteId = nil
    familyUnit = nil
  }

  /// A load that outlives its user (sign-out or account switch mid-request) must not
  /// write that user's family into the next session.
  private func isStillSignedIn(_ userId: String) -> Bool {
    guard authManager.user?.id == userId else {
      logger.debug("Discarding family data loaded for a user who is no longer signed in")
      return false
    }
    return true
  }

}
