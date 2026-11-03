import Foundation
import Testing
@testable import TheRecruitingCompass

@Suite("FamilyManager — multi-family parent (#228)")
@MainActor
struct FamilyManagerMultiFamilyTests {
  private let parentUser = User(
    id: "parent-1",
    email: "parent-1@example.com",
    emailConfirmedAt: nil,
    createdAt: "2024-01-01T00:00:00Z",
    updatedAt: "2024-01-01T00:00:00Z",
    role: .parent
  )

  private func member(_ id: String, family: String, role: String, userId: String? = nil) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: userId ?? "u-\(id)",
      familyUnitId: family,
      role: role,
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
  }

  private func freshDefaults() -> UserDefaults {
    let name = "family-manager-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  /// Parent in family-new (joined last, no player) and family-old (has a player).
  private func makeSUT(
    defaults: UserDefaults? = nil
  ) -> (FamilyManager, MockFamilyService, UserDefaults) {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    auth.setMockUser(parentUser)
    let store = defaults ?? freshDefaults()
    service.stubbedMemberships = [
      member("pm-new", family: "family-new", role: "parent", userId: "parent-1"),
      member("pm-old", family: "family-old", role: "parent", userId: "parent-1")
    ]
    service.familyUnitIdsWithPlayerStub = ["family-old"]
    service.membersByFamilyUnitId = [
      "family-new": [member("pm-new", family: "family-new", role: "parent", userId: "parent-1")],
      "family-old": [
        member("pm-old", family: "family-old", role: "parent", userId: "parent-1"),
        member("ath-old", family: "family-old", role: "player")
      ]
    ]
    let sut = FamilyManager(familyService: service, authManager: auth, defaults: store)
    return (sut, service, store)
  }

  @Test func defaultsToMostRecentFamilyThatHasAPlayer() async {
    let (sut, _, _) = makeSUT()

    await sut.loadFamilyData()

    #expect(sut.familyUnitId == "family-old")
    #expect(sut.selectedAthleteId == "ath-old")
  }

  @Test func defaultsToMostRecentFamilyWhenNoneHasAPlayer() async {
    let (sut, service, _) = makeSUT()
    service.familyUnitIdsWithPlayerStub = []

    await sut.loadFamilyData()

    #expect(sut.familyUnitId == "family-new")
  }

  @Test func switchingFamilyScopesEverythingToTheSelectedFamily() async {
    let (sut, _, _) = makeSUT()
    await sut.loadFamilyData()

    await sut.switchFamily(to: "family-new")

    #expect(sut.familyUnitId == "family-new")
    #expect(sut.currentMember?.familyUnitId == "family-new")
    #expect(sut.resolvedFamilyUnitId == "family-new")
    #expect(sut.familyMembers.map(\.familyUnitId) == ["family-new"])
    #expect(sut.selectedAthleteId == nil)
  }

  @Test func selectionPersistsAcrossLaunches() async {
    // No family has a player, so the default is family-new; the saved choice must beat it.
    let (first, firstService, defaults) = makeSUT()
    firstService.familyUnitIdsWithPlayerStub = []
    await first.loadFamilyData()
    await first.switchFamily(to: "family-old")

    let (relaunched, relaunchedService, _) = makeSUT(defaults: defaults)
    relaunchedService.familyUnitIdsWithPlayerStub = []
    await relaunched.loadFamilyData()

    #expect(relaunched.familyUnitId == "family-old")
  }

  @Test func savedFamilyTheParentNoLongerBelongsToFallsBackToTheDefault() async {
    let defaults = freshDefaults()
    defaults.set("family-gone", forKey: "selectedFamilyId.parent-1")
    let (sut, _, _) = makeSUT(defaults: defaults)

    await sut.loadFamilyData()

    #expect(sut.familyUnitId == "family-old")
  }

  @Test func switchingToAFamilyTheParentDoesNotBelongToIsIgnored() async {
    let (sut, _, _) = makeSUT()
    await sut.loadFamilyData()

    await sut.switchFamily(to: "someone-elses-family")

    #expect(sut.familyUnitId == "family-old")
  }

  @Test func switcherListsEachFamilyByItsServerLabel() async {
    let (sut, _, _) = makeSUT()
    await sut.loadFamilyData()
    sut.familyLabels = ["family-new": "Maya's Family", "family-old": "Alex's Family"]

    #expect(sut.familyChoices.map(\.label) == ["Maya's Family", "Alex's Family"])
    #expect(sut.familyChoices.map(\.id) == ["family-new", "family-old"])
  }
}

@Suite("FamilySelection")
struct FamilySelectionTests {
  private func member(_ family: String) -> FamilyMember {
    FamilyMember(id: "m-\(family)", userId: "u", familyUnitId: family, role: "parent", addedAt: nil, user: nil)
  }

  @Test func savedFamilyWinsWhileStillAMember() {
    let result = FamilySelection.resolve(
      memberships: [member("a"), member("b")],
      familyIdsWithPlayer: ["a"],
      savedFamilyId: "b"
    )
    #expect(result == "b")
  }

  @Test func noMembershipsResolvesToNil() {
    #expect(FamilySelection.resolve(memberships: [], familyIdsWithPlayer: [], savedFamilyId: "x") == nil)
  }

  @Test func choicesDeduplicateFamiliesAndFallBackToAGenericLabel() {
    let choices = FamilySelection.choices(
      memberships: [member("a"), member("a"), member("b")],
      labels: ["a": "A's Family"]
    )
    #expect(choices.map(\.label) == ["A's Family", "Family"])
  }
}
