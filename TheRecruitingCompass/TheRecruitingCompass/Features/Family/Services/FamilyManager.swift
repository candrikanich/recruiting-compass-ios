import Foundation
import SwiftUI
import Combine

@MainActor
final class FamilyManager: ObservableObject {
  static let shared = FamilyManager()

  @Published var currentMember: FamilyMember?
  @Published var familyMembers: [FamilyMember] = []
  @Published var selectedAthleteId: String?

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

  nonisolated init(
    familyService: any FamilyManaging = FamilyServiceImpl(supabaseManager: .shared),
    authManager: any AuthManaging = AuthManager.shared
  ) {
    self.familyService = familyService
    self.authManager = authManager
  }

  func loadFamilyData() async {
    guard let userId = authManager.user?.id else { return }

    do {
      currentMember = try await familyService.getCurrentMember(userId: userId)

      if let familyUnitId = currentMember?.familyUnitId {
        familyMembers = try await familyService.fetchFamilyMembers(familyUnitId: familyUnitId)

        if currentMember?.isAthlete == true {
          selectedAthleteId = currentMember?.id
        }
      }
    } catch {
      print("Failed to load family data: \(error)")
    }
  }

  func selectAthlete(_ athleteId: String?) {
    selectedAthleteId = athleteId
  }

  func clearAthleteSelection() {
    selectedAthleteId = nil
  }
}
