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

  /// Parent in family-new (joined last, player graduates 2029) and family-old (player graduates 2027).
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
    service.familyPlayersStub = [
      FamilyPlayer(familyUnitId: "family-new", graduationYear: 2029),
      FamilyPlayer(familyUnitId: "family-old", graduationYear: 2027)
    ]
    service.membersByFamilyUnitId = [
      "family-new": [
        member("pm-new", family: "family-new", role: "parent", userId: "parent-1"),
        member("ath-new", family: "family-new", role: "player")
      ],
      "family-old": [
        member("pm-old", family: "family-old", role: "parent", userId: "parent-1"),
        member("ath-old", family: "family-old", role: "player")
      ]
    ]
    let sut = FamilyManager(familyService: service, authManager: auth, defaults: store)
    return (sut, service, store)
  }

  @Test func defaultsToTheFamilyWhosePlayerIsClosestToGraduation() async {
    let (sut, _, _) = makeSUT()

    await sut.loadFamilyData()

    #expect(sut.familyUnitId == "family-old")
    #expect(sut.selectedAthleteId == "ath-old")
  }

  @Test func equalOrMissingGraduationYearsFallBackToMostRecentlyJoined() async {
    let (sut, service, _) = makeSUT()
    service.familyPlayersStub = [
      FamilyPlayer(familyUnitId: "family-new", graduationYear: nil),
      FamilyPlayer(familyUnitId: "family-old", graduationYear: nil)
    ]

    await sut.loadFamilyData()

    #expect(sut.familyUnitId == "family-new")
  }

  @Test func noPlayersAnywhereFallsBackToMostRecentlyJoined() async {
    let (sut, service, _) = makeSUT()
    service.familyPlayersStub = []

    await sut.loadFamilyData()

    #expect(sut.familyUnitId == "family-new")
  }

  @Test func switchingFamilyScopesEverythingToTheSelectedFamilyAndRebuildsViews() async {
    let (sut, _, _) = makeSUT()
    await sut.loadFamilyData()
    #expect(sut.familySwitchCount == 0)

    await sut.switchFamily(to: "family-new")

    #expect(sut.familyUnitId == "family-new")
    #expect(sut.currentMember?.familyUnitId == "family-new")
    #expect(sut.resolvedFamilyUnitId == "family-new")
    #expect(sut.familyMembers.map(\.familyUnitId) == ["family-new", "family-new"])
    #expect(sut.selectedAthleteId == "ath-new")
    #expect(sut.familySwitchCount == 1)
  }

  @Test func reselectingTheCurrentFamilyDoesNotRebuildViews() async {
    let (sut, _, _) = makeSUT()
    await sut.loadFamilyData()

    await sut.switchFamily(to: "family-old")

    #expect(sut.familySwitchCount == 0)
  }

  @Test func selectionPersistsAcrossLaunches() async {
    // The default is family-old; the saved choice must beat it.
    let (first, _, defaults) = makeSUT()
    await first.loadFamilyData()
    await first.switchFamily(to: "family-new")

    let (relaunched, _, _) = makeSUT(defaults: defaults)
    await relaunched.loadFamilyData()

    #expect(relaunched.familyUnitId == "family-new")
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

  @Test func unlabelledFamiliesStayDistinguishable() async {
    let (sut, _, _) = makeSUT()
    await sut.loadFamilyData()

    let labels = sut.familyChoices.map(\.label)
    #expect(Set(labels).count == 2)
  }

  @Test func aLoadInFlightWhenTheUserSwitchesDoesNotRestoreTheOldFamily() async {
    let (sut, service, defaults) = makeSUT()
    let gate = AsyncGate()
    service.fetchFamilyMembersGate = { familyId in
      if familyId == "family-old" { await gate.wait() }
    }

    let load = Task { await sut.loadFamilyData() }
    await gate.untilEntered()
    await sut.switchFamily(to: "family-new")
    gate.open()
    await load.value

    #expect(sut.familyUnitId == "family-new")
    #expect(sut.selectedAthleteId == "ath-new")
    #expect(defaults.string(forKey: "selectedFamilyId.parent-1") == "family-new")
  }

  @Test func lastPickedFamilyWinsWhenSwitchesOverlap() async {
    let (sut, service, defaults) = makeSUT()
    await sut.loadFamilyData()
    let gate = AsyncGate()
    service.fetchFamilyMembersGate = { familyId in
      if familyId == "family-new" { await gate.wait() }
    }

    let slowSwitch = Task { await sut.switchFamily(to: "family-new") }
    await gate.untilEntered()
    await sut.switchFamily(to: "family-old")
    gate.open()
    await slowSwitch.value

    #expect(sut.familyUnitId == "family-old")
    #expect(defaults.string(forKey: "selectedFamilyId.parent-1") == "family-old")
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
      players: [FamilyPlayer(familyUnitId: "a", graduationYear: 2026)],
      savedFamilyId: "b"
    )
    #expect(result == "b")
  }

  @Test func closestGraduationWinsAndFamiliesWithoutAYearComeLast() {
    let result = FamilySelection.resolve(
      memberships: [member("a"), member("b"), member("c")],
      players: [
        FamilyPlayer(familyUnitId: "a", graduationYear: nil),
        FamilyPlayer(familyUnitId: "b", graduationYear: 2029),
        FamilyPlayer(familyUnitId: "c", graduationYear: 2027)
      ],
      savedFamilyId: nil
    )
    #expect(result == "c")
  }

  @Test func aFamilyWithSeveralPlayersCountsItsClosestGraduation() {
    let result = FamilySelection.resolve(
      memberships: [member("a"), member("b")],
      players: [
        FamilyPlayer(familyUnitId: "a", graduationYear: 2028),
        FamilyPlayer(familyUnitId: "b", graduationYear: 2030),
        FamilyPlayer(familyUnitId: "b", graduationYear: 2026)
      ],
      savedFamilyId: nil
    )
    #expect(result == "b")
  }

  @Test func noMembershipsResolvesToNil() {
    #expect(FamilySelection.resolve(memberships: [], players: [], savedFamilyId: "x") == nil)
  }

  @Test func choicesDeduplicateFamiliesAndNumberUnlabelledOnes() {
    let choices = FamilySelection.choices(
      memberships: [member("a"), member("a"), member("b")],
      labels: ["a": "A's Family"]
    )
    #expect(choices.map(\.label) == ["A's Family", "Family 2"])
  }
}
