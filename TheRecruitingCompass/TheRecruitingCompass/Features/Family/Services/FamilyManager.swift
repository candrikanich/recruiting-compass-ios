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
  /// Drives the family-required gate. Stays `unknown` until the first read finishes (loading is not "no family").
  private(set) var membership: FamilyMembershipStatus = .unknown
  /// Server-resolved family labels by family unit id (from `/api/family/inbound-address`); empty on API versions
  /// without `familyLabel`, in which case the athlete switcher shows no family text.
  var familyLabels: [String: String] = [:]
  /// Every family the user belongs to, most recently joined first. A parent can be in several (web#1243).
  private(set) var memberships: [FamilyMember] = []
  /// Bumped whenever the user switches family, so the root views can rebuild and drop the old family's state.
  private(set) var familySwitchCount = 0

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
  private let inboundDraftsService: any InboundDraftsAPIManaging
  private let defaults: UserDefaults

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

  /// The family every family-scoped read and write uses: the selected one for a multi-family parent.
  var familyUnitId: String? {
    if let familyUnitId = currentMember?.familyUnitId {
      return familyUnitId
    }
    return familyUnit?.id
  }

  /// One entry per family, labelled by its player; the switcher only shows when there are two or more.
  var familyChoices: [FamilySelection.Choice] {
    FamilySelection.choices(memberships: memberships, labels: familyLabels)
  }

  /// `familyUnitId` normalized for inserts: nil (never "") when no family is loaded yet.
  var resolvedFamilyUnitId: String? { FamilyUnitID.normalized(familyUnitId) }

  init(
    familyService: (any FamilyManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    inboundDraftsService: (any InboundDraftsAPIManaging)? = nil,
    defaults: UserDefaults = .standard
  ) {
    self.defaults = defaults
    self.inboundDraftsService = inboundDraftsService ?? InboundDraftsAPIService()
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
      let all = try await familyService.getMemberships(userId: userId)
      guard isCurrent(userId, loadSession) else { return }
      memberships = all

      let withPlayer = all.count > 1
        ? try await familyService.familyUnitIdsWithPlayer(among: all.map(\.familyUnitId))
        : []
      guard isCurrent(userId, loadSession) else { return }

      // No client auto-create: the server creates the family at signup and the family-required gate is the
      // backstop for anyone left without one.
      if let familyId = FamilySelection.resolve(
        memberships: all,
        familyIdsWithPlayer: withPlayer,
        savedFamilyId: defaults.string(forKey: Self.savedFamilyKey(userId))
      ) {
        guard try await activate(familyId: familyId, userId: userId, session: loadSession) else { return }
      } else {
        logger.warning("No family unit ID found for user \(userId)")
        // Left or removed from the last family: drop its cached rows too.
        currentMember = nil
        familyUnit = nil
        familyMembers = []
        selectedAthleteId = nil
        membership = FamilyGate.status(afterReading: nil)
      }
      await loadFamilyLabels(userId: userId, session: loadSession)
    } catch {
      logger.error("Failed to load family data: \(error.localizedDescription)")
      if isCurrent(userId, loadSession) {
        membership = FamilyGate.status(afterFailedReadFrom: membership)
      }
    }
  }

  /// Makes `familyId` the family everything reads from. Returns false when the session ended mid-request.
  private func activate(familyId: String, userId: String, session loadSession: Int) async throws -> Bool {
    let unit = try await familyService.getFamilyUnit(id: familyId)
    let members = try await familyService.fetchFamilyMembers(familyUnitId: familyId)
    guard isCurrent(userId, loadSession) else { return false }

    currentMember = memberships.first { $0.familyUnitId == familyId }
    familyUnit = unit
    membership = FamilyGate.status(afterReading: self.familyUnitId)
    familyMembers = members

    if currentMember?.isAthlete == true {
      selectedAthleteId = currentMember?.id
    } else if currentMember?.isParent == true, !familyMembers.contains(where: { $0.id == selectedAthleteId }) {
      // Nothing selected, or the selection belonged to another family the parent left or switched away from.
      // Mirror web: a parent auto-views an athlete. Web sorts by closest graduation year; that field isn't
      // loaded here, so default to the first linked athlete (deterministic for single-athlete families).
      selectedAthleteId = familyMembers.first { $0.isAthlete }?.id
    }
    return true
  }

  /// Switches a multi-family parent to another family they belong to and remembers the choice per user.
  func switchFamily(to familyId: String) async {
    guard familyId != familyUnitId,
          memberships.contains(where: { $0.familyUnitId == familyId }),
          let userId = authManager.user?.id else { return }
    do {
      guard try await activate(familyId: familyId, userId: userId, session: session) else { return }
      defaults.set(familyId, forKey: Self.savedFamilyKey(userId))
      familySwitchCount += 1
    } catch {
      logger.error("Failed to switch family: \(error.localizedDescription)")
    }
  }

  private static func savedFamilyKey(_ userId: String) -> String { "selectedFamilyId.\(userId)" }

  /// Display-only, so a failure leaves the switcher without family text rather than failing the load.
  private func loadFamilyLabels(userId: String, session loadSession: Int) async {
    do {
      let token = authManager.session?.accessToken
      let addresses = try await inboundDraftsService.fetchForwardingAddress(accessToken: token)
      guard isCurrent(userId, loadSession) else { return }
      familyLabels = Dictionary(
        addresses.compactMap { entry in
          FamilyLabel.display(label: entry.familyLabel, legacyName: nil).map { (entry.familyUnitId, $0) }
        },
        uniquingKeysWith: { first, _ in first }
      )
    } catch {
      logger.error("Failed to load family labels: \(error.localizedDescription)")
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
    memberships = []
    familyMembers = []
    selectedAthleteId = nil
    familyUnit = nil
    familyLabels = [:]
    membership = .unknown
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
