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

  /// Advanced by `reset()`. A load only writes while its session is still current, so a request
  /// from before a sign-out can't land in a later session — even one for the same user.
  private var session = 0
  /// The load currently in flight. Concurrent callers in the same session await it instead of
  /// returning early with whatever state is already here.
  private var inFlightLoad: InFlightLoad?

  private struct InFlightLoad {
    let userId: String
    let session: Int
    let task: Task<Void, Never>
  }
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
    if let inFlight = inFlightLoad, inFlight.userId == userId, inFlight.session == session {
      await inFlight.task.value
      return
    }
    let loadSession = session
    let task = Task { await performLoad(userId: userId, session: loadSession) }
    inFlightLoad = InFlightLoad(userId: userId, session: loadSession, task: task)
    await task.value
    if inFlightLoad?.task == task {
      inFlightLoad = nil
    }
  }

  private func performLoad(userId: String, session loadSession: Int) async {
    do {
      // Try to get family member record (works for all family members)
      let member = try await familyService.getCurrentMember(userId: userId)
      guard isCurrent(userId, loadSession) else { return }
      currentMember = member

      // Also fetch family unit via membership (works for all roles)
      let unit = try await familyService.getFamilyUnit(forUserId: userId)
      guard isCurrent(userId, loadSession) else { return }
      familyUnit = unit
      logger.debug("Fetched family unit: \(self.familyUnit?.id ?? "none")")

      // Mirrors web: no auto-create. User creates family from Family tab when inviting parent.
      if let familyUnitId = self.familyUnitId {
        let members = try await familyService.fetchFamilyMembers(familyUnitId: familyUnitId)
        guard isCurrent(userId, loadSession) else { return }
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
    session += 1
    inFlightLoad = nil
    currentMember = nil
    familyMembers = []
    selectedAthleteId = nil
    familyUnit = nil
  }

  /// A load that outlives its session (sign-out or account switch mid-request) must not
  /// write into the next one.
  private func isCurrent(_ userId: String, _ loadSession: Int) -> Bool {
    guard loadSession == session, authManager.user?.id == userId else {
      logger.debug("Discarding family data loaded for a previous session")
      return false
    }
    return true
  }

}
