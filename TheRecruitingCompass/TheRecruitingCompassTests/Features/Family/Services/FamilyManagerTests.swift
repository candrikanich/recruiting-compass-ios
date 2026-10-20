import Foundation
import Testing
@testable import TheRecruitingCompass

@Suite("FamilyManager — account switching")
@MainActor
struct FamilyManagerTests {

  private func user(_ id: String, role: UserRole) -> User {
    User(
      id: id,
      email: "\(id)@example.com",
      emailConfirmedAt: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role
    )
  }

  private func member(id: String, userId: String, familyUnitId: String, role: String) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: userId,
      familyUnitId: familyUnitId,
      role: role,
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
  }

  @Test func resetClearsEverythingTiedToThePreviousUser() {
    let sut = FamilyManager(familyService: MockFamilyService(), authManager: MockAuthManager())
    let athlete = member(id: "m-a", userId: "user-a", familyUnitId: "family-a", role: "player")
    sut.currentMember = athlete
    sut.familyMembers = [athlete]
    sut.selectedAthleteId = athlete.id

    sut.reset()

    #expect(sut.currentMember == nil)
    #expect(sut.familyMembers.isEmpty)
    #expect(sut.selectedAthleteId == nil)
    #expect(sut.familyUnit == nil)
    #expect(sut.familyUnitId == nil)
  }

  @Test func parentSwitchingAccountsSelectsTheirOwnAthlete() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    let sut = FamilyManager(familyService: service, authManager: auth)
    sut.selectedAthleteId = "m-athlete-from-previous-family"

    auth.setMockUser(user("parent-b", role: .parent))
    sut.reset()
    let parentB = member(id: "m-parent-b", userId: "parent-b", familyUnitId: "family-b", role: "parent")
    let athleteB = member(id: "m-athlete-b", userId: "athlete-b", familyUnitId: "family-b", role: "player")
    service.stubbedCurrentMember = parentB
    service.stubbedFamilyMembers = [parentB, athleteB]
    await sut.loadFamilyData()

    #expect(sut.selectedAthleteId == "m-athlete-b")
  }

  @Test func parentWhoLeftTheSelectedAthletesFamilyIsMovedToAnAthleteInARemainingFamily() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    let sut = FamilyManager(familyService: service, authManager: auth)
    sut.selectedAthleteId = "m-athlete-a"
    let parentB = member(id: "m-parent-b", userId: "parent-1", familyUnitId: "family-b", role: "parent")
    let athleteB = member(id: "m-athlete-b", userId: "athlete-b", familyUnitId: "family-b", role: "player")
    service.stubbedCurrentMember = parentB
    service.stubbedFamilyMembers = [parentB, athleteB]

    await sut.loadFamilyData()

    #expect(sut.selectedAthleteId == "m-athlete-b")
  }

  @Test func parentKeepsTheirSelectedAthleteWhileTheyStillShareAFamily() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    let sut = FamilyManager(familyService: service, authManager: auth)
    let parent = member(id: "m-parent", userId: "parent-1", familyUnitId: "family-a", role: "parent")
    let first = member(id: "m-athlete-1", userId: "athlete-1", familyUnitId: "family-a", role: "player")
    let second = member(id: "m-athlete-2", userId: "athlete-2", familyUnitId: "family-a", role: "player")
    sut.selectedAthleteId = "m-athlete-2"
    service.stubbedCurrentMember = parent
    service.stubbedFamilyMembers = [parent, first, second]

    await sut.loadFamilyData()

    #expect(sut.selectedAthleteId == "m-athlete-2")
  }

  @Test func concurrentLoadWaitsForTheLoadAlreadyInFlight() async {
    let service = MockFamilyService()
    let gate = AsyncGate()
    service.getCurrentMemberGate = { await gate.wait() }
    service.stubbedCurrentMember = member(id: "m-a", userId: "user-a", familyUnitId: "family-a", role: "player")
    let auth = MockAuthManager()
    auth.setMockUser(user("user-a", role: .player))
    let sut = FamilyManager(familyService: service, authManager: auth)

    let first = Task { await sut.loadFamilyData() }
    await gate.untilEntered()
    let second = Task { () -> String? in
      await sut.loadFamilyData()
      return sut.familyUnitId
    }
    for _ in 0..<5 { await Task.yield() }
    gate.open()

    #expect(await second.value == "family-a")
    await first.value
    #expect(service.getCurrentMemberCallCount == 1)
  }

  @Test func loadStartedForPreviousUserIsDiscardedAfterSwitch() async {
    let service = MockFamilyService()
    let gate = AsyncGate()
    service.getCurrentMemberGate = { await gate.wait() }
    service.stubbedCurrentMember = member(id: "m-a", userId: "user-a", familyUnitId: "family-a", role: "player")
    let auth = MockAuthManager()
    auth.setMockUser(user("user-a", role: .player))
    let sut = FamilyManager(familyService: service, authManager: auth)

    let staleLoad = Task { await sut.loadFamilyData() }
    await gate.untilEntered()
    auth.setMockUser(user("user-b", role: .player))
    sut.reset()
    gate.open()
    await staleLoad.value

    #expect(sut.currentMember == nil)
    #expect(sut.familyUnitId == nil)
    #expect(sut.familyMembers.isEmpty)
  }

  @Test func loadFromAnEarlierSessionOfTheSameUserIsDiscarded() async {
    let service = MockFamilyService()
    let gate = AsyncGate(blockedEntries: 1)
    service.getCurrentMemberGate = { await gate.wait() }
    let auth = MockAuthManager()
    auth.setMockUser(user("user-a", role: .player))
    let sut = FamilyManager(familyService: service, authManager: auth)

    let staleLoad = Task { await sut.loadFamilyData() }
    await gate.untilEntered()
    auth.setMockUser(user("user-b", role: .player))
    sut.reset()
    auth.setMockUser(user("user-a", role: .player))
    sut.reset()
    service.stubbedCurrentMember = member(id: "m-a", userId: "user-a", familyUnitId: "family-new", role: "player")
    await sut.loadFamilyData()

    service.stubbedCurrentMember = member(id: "m-a", userId: "user-a", familyUnitId: "family-old", role: "player")
    gate.open()
    await staleLoad.value

    #expect(sut.familyUnitId == "family-new")
  }

  @Test func loadsServerFamilyLabelsAndIgnoresMissingOnes() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-a", role: .parent))
    let inbound = MockInboundDraftsAPIService()
    inbound.addressesToReturn = [
      InboundFamilyAddress(familyUnitId: "family-a", familyName: "My Family", familyLabel: "Alex's Family", address: "x"),
      InboundFamilyAddress(familyUnitId: "family-b", familyName: "My Family", address: "y")
    ]
    service.stubbedCurrentMember = member(id: "m-p", userId: "parent-a", familyUnitId: "family-a", role: "parent")
    let sut = FamilyManager(familyService: service, authManager: auth, inboundDraftsService: inbound)

    await sut.loadFamilyData()

    #expect(sut.familyLabels == ["family-a": "Alex's Family"])
    sut.reset()
    #expect(sut.familyLabels.isEmpty)
  }

  // MARK: - Family-required gate state (#396)

  @Test func membershipStaysUnknownUntilTheFirstReadFinishes() {
    let sut = FamilyManager(familyService: MockFamilyService(), authManager: MockAuthManager())
    #expect(sut.membership == .unknown)
  }

  @Test func userWithAFamilyIsAMember() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    service.stubbedCurrentMember = member(id: "m1", userId: "parent-1", familyUnitId: "family-1", role: "parent")
    let sut = FamilyManager(familyService: service, authManager: auth)

    await sut.loadFamilyData()

    #expect(sut.membership == .member)
  }

  @Test func userWithNoFamilyIsGated() async {
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    let sut = FamilyManager(familyService: MockFamilyService(), authManager: auth)

    await sut.loadFamilyData()

    #expect(sut.membership == FamilyMembershipStatus.none)
  }

  @Test func failedFirstReadFailsClosedInsteadOfGatingOrAdmitting() async {
    let service = MockFamilyService()
    service.shouldSucceed = false
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    let sut = FamilyManager(familyService: service, authManager: auth)

    await sut.loadFamilyData()

    #expect(sut.membership == .failed)
  }

  @Test func failedRefreshNeverDemotesAKnownMember() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    service.stubbedCurrentMember = member(id: "m1", userId: "parent-1", familyUnitId: "family-1", role: "parent")
    let sut = FamilyManager(familyService: service, authManager: auth)
    await sut.loadFamilyData()

    service.shouldSucceed = false
    await sut.loadFamilyData()

    #expect(sut.membership == .member)
  }

  @Test func leavingTheLastFamilyRoutesToTheGate() async {
    let service = MockFamilyService()
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    service.stubbedCurrentMember = member(id: "m1", userId: "parent-1", familyUnitId: "family-1", role: "parent")
    let sut = FamilyManager(familyService: service, authManager: auth)
    await sut.loadFamilyData()

    service.stubbedCurrentMember = nil
    await sut.loadFamilyData()

    #expect(sut.membership == FamilyMembershipStatus.none)
  }

  @Test func resetReturnsToUnknownSoANewAccountIsNeverGatedOnStaleState() async {
    let auth = MockAuthManager()
    auth.setMockUser(user("parent-1", role: .parent))
    let sut = FamilyManager(familyService: MockFamilyService(), authManager: auth)
    await sut.loadFamilyData()

    sut.reset()

    #expect(sut.membership == .unknown)
  }
}
