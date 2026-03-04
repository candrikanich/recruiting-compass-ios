import Foundation
import OSLog
import SwiftUI
import Observation

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyManager")

@Observable
@MainActor
final class FamilyManager {
  static let shared = FamilyManager()

  var currentMember: FamilyMember?
  var familyMembers: [FamilyMember] = []
  var selectedAthleteId: String?
  var familyUnit: FamilyUnit?

  private var isLoadingFamilyData = false
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
    guard !isLoadingFamilyData, let userId = authManager.user?.id else { return }
    isLoadingFamilyData = true
    defer { isLoadingFamilyData = false }

    do {
      // Try to get family member record (works for all family members)
      currentMember = try await familyService.getCurrentMember(userId: userId)

      // Also fetch family unit via membership (works for all roles)
      familyUnit = try await familyService.getFamilyUnit(forUserId: userId)
      logger.debug("Fetched family unit: \(self.familyUnit?.id ?? "none")")

      // Mirrors web: no auto-create. User creates family from Family tab when inviting parent.
      if let familyUnitId = self.familyUnitId {
        familyMembers = try await familyService.fetchFamilyMembers(familyUnitId: familyUnitId)

        if currentMember?.isAthlete == true {
          selectedAthleteId = currentMember?.id
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

  nonisolated deinit {}
}
