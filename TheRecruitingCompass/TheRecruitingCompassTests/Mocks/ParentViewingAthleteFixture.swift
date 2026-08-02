import Foundation
@testable import TheRecruitingCompass

/// Family state for the "parent signed in, athlete selected" case that athlete-owned
/// ViewModels must resolve to the athlete's userId rather than the signed-in parent's.
enum ParentViewingAthleteFixture {
  static let parentUserId = "parent-user-1"
  static let athleteUserId = "athlete-user-1"
  static let familyUnitId = "family-1"

  static func parentUser() -> User {
    User(
      id: parentUserId,
      email: "parent@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: .parent
    )
  }

  /// Builds a FamilyManager whose current member is a parent with the athlete selected,
  /// and points `authManager` at the parent user.
  @MainActor
  static func makeFamilyManager(authManager: MockAuthManager) -> FamilyManager {
    let parent = member(id: "member-parent-1", userId: parentUserId, role: "parent")
    let athlete = member(id: "member-athlete-1", userId: athleteUserId, role: "player")

    authManager.setMockUser(parentUser())

    let familyManager = FamilyManager(familyService: MockFamilyService(), authManager: authManager)
    familyManager.currentMember = parent
    familyManager.familyMembers = [parent, athlete]
    familyManager.selectedAthleteId = athlete.id
    return familyManager
  }

  private static func member(id: String, userId: String, role: String) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: userId,
      familyUnitId: familyUnitId,
      role: role,
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
  }
}
