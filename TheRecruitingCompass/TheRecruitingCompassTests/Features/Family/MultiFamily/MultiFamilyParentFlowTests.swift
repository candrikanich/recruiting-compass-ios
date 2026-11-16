import XCTest
@testable import TheRecruitingCompass

/// A parent in two families (#604): joining a second one by Family Code and leaving one of two, driven the way
/// `FamilyManagementView` wires `FamilyManagementViewModel` to `FamilyManager`.
@MainActor
final class MultiFamilyParentFlowTests: XCTestCase {
  nonisolated deinit {}

  private let parentId = "parent-1"
  private var service: MockFamilyService!
  private var auth: MockAuthManager!
  private var manager: FamilyManager!
  private var management: FamilyManagementViewModel!

  override func setUp() async throws {
    service = MockFamilyService()
    auth = MockAuthManager()
    auth.setMockUser(
      User(
        id: parentId, email: "parent@test.com", emailConfirmedAt: nil, fullName: nil,
        createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z", role: .parent, dateOfBirth: nil
      )
    )
    let defaults = UserDefaults(suiteName: "multi-family-flow-\(UUID().uuidString)")!
    manager = FamilyManager(familyService: service, authManager: auth, defaults: defaults)
    management = FamilyManagementViewModel(
      familyService: service, authManager: auth, inboundDraftsService: MockInboundDraftsAPIService()
    )
    management.onMembershipChanged = { [manager] in await manager?.loadFamilyData(forceFresh: true) }
    service.membersByFamilyUnitId = [
      "family-home": [
        member("pm-home", "family-home", role: "parent", userId: parentId), member("ath-home", "family-home")
      ],
      "family-joined": [
        member("pm-joined", "family-joined", role: "parent", userId: parentId), member("ath-joined", "family-joined")
      ]
    ]
    service.familyPlayersStub = [
      FamilyPlayer(familyUnitId: "family-home", graduationYear: 2027),
      FamilyPlayer(familyUnitId: "family-joined", graduationYear: 2030)
    ]
  }

  override func tearDown() async throws {
    service = nil
    auth = nil
    manager = nil
    management = nil
  }

  private func member(_ id: String, _ family: String, role: String = "player", userId: String? = nil) -> FamilyMember {
    FamilyMember(
      id: id, userId: userId ?? "u-\(id)", familyUnitId: family, role: role,
      addedAt: "2024-01-01T00:00:00Z", user: nil
    )
  }

  private func parentFamily(_ id: String) -> ParentFamilyData {
    ParentFamilyData(familyId: id, familyCode: "FAM-\(id)", familyName: id, codeGeneratedAt: "x")
  }

  private var homeMembership: FamilyMember { member("pm-home", "family-home", role: "parent", userId: parentId) }
  private var joinedMembership: FamilyMember { member("pm-joined", "family-joined", role: "parent", userId: parentId) }

  // MARK: - Gap 1: join a second family

  func test_joiningASecondFamilyByCode_showsTheSwitcherWithBothFamilies() async {
    service.stubbedMemberships = [homeMembership]
    await manager.loadFamilyData()
    XCTAssertEqual(manager.familyChoices.count, 1, "one family: no switcher yet")

    service.stubbedMemberships = [joinedMembership, homeMembership]
    service.mockParentFamilies = [parentFamily("family-joined"), parentFamily("family-home")]
    management.codeInput = "FAM-JOIN01"
    await management.joinFamily()

    XCTAssertEqual(service.lastFamilyCodeJoined, "FAM-JOIN01")
    XCTAssertEqual(manager.memberships.map(\.familyUnitId), ["family-joined", "family-home"])
    XCTAssertEqual(manager.familyChoices.map(\.id), ["family-joined", "family-home"])
  }

  func test_joiningASecondFamily_keepsTheCurrentFamilySelectedUntilTheParentSwitches() async {
    service.stubbedMemberships = [homeMembership]
    await manager.loadFamilyData()

    service.stubbedMemberships = [joinedMembership, homeMembership]
    service.mockParentFamilies = [parentFamily("family-joined"), parentFamily("family-home")]
    management.codeInput = "FAM-JOIN01"
    await management.joinFamily()

    XCTAssertEqual(manager.familyUnitId, "family-home", "joining must not silently move the parent into family B")
    XCTAssertEqual(manager.familySwitchCount, 0)

    await manager.switchFamily(to: "family-joined")

    XCTAssertEqual(manager.familyUnitId, "family-joined")
    XCTAssertEqual(manager.selectedAthleteId, "ath-joined")
    XCTAssertEqual(manager.familySwitchCount, 1)
  }

  func test_aRejectedFamilyCode_leavesMembershipsAndSwitcherUntouched() async {
    service.stubbedMemberships = [homeMembership]
    await manager.loadFamilyData()
    service.shouldSucceed = false
    service.mockError = FamilyError.serverError("That code didn't match a family.")
    management.codeInput = "FAM-NOPE00"

    await management.joinFamily()

    XCTAssertEqual(management.errorMessage, "That code didn't match a family.")
    XCTAssertEqual(manager.memberships.map(\.familyUnitId), ["family-home"])
    XCTAssertEqual(manager.familyChoices.count, 1)
  }

  func test_aFamilyLoadAlreadyInFlightWhenTheJoinCommitsDoesNotAnswerForTheNewMembership() async {
    service.stubbedMemberships = [homeMembership]
    service.snapshotMembershipsBeforeGate = true
    let gate = AsyncGate(blockedEntries: 1)
    service.getMembershipsGate = { await gate.wait() }
    let staleLoad = Task { await manager.loadFamilyData() }
    let entered = await gate.untilEntered()
    XCTAssertTrue(entered)

    service.stubbedMemberships = [joinedMembership, homeMembership]
    service.mockParentFamilies = [parentFamily("family-joined"), parentFamily("family-home")]
    var reachedRefresh = false
    management.onMembershipChanged = { [manager] in
      reachedRefresh = true
      await manager?.loadFamilyData(forceFresh: true)
    }
    management.codeInput = "FAM-JOIN01"
    let join = Task { await management.joinFamily() }
    while !reachedRefresh { await Task.yield() }
    gate.open()
    await staleLoad.value
    await join.value

    XCTAssertEqual(manager.memberships.map(\.familyUnitId), ["family-joined", "family-home"])
    XCTAssertEqual(manager.familyChoices.count, 2)
  }

  // MARK: - Gap 1: invite accepted by a signed-in parent

  func test_acceptingAnInviteWhileSignedIn_joinsTheSecondFamilyAndShowsTheSwitcher() async {
    service.stubbedMemberships = [homeMembership]
    await manager.loadFamilyData()
    let invite = InviteJoinViewModel(
      token: "invite-token-9",
      familyService: service,
      authManager: auth,
      turnstileTokenProvider: MockTurnstileTokenProvider(),
      profileService: MockProfileService()
    )
    auth.isAuthenticated = true
    service.stubbedMemberships = [joinedMembership, homeMembership]

    await invite.accept()
    // The invite sheet's onDismiss (TheRecruitingCompassApp) reloads the family data.
    await manager.loadFamilyData()

    XCTAssertEqual(service.lastAcceptedToken, "invite-token-9")
    XCTAssertEqual(service.acceptInviteCallCount, 1)
    XCTAssertEqual(auth.loginCallCount, 0, "a signed-in parent accepts without logging in again")
    XCTAssertEqual(manager.familyChoices.map(\.id), ["family-joined", "family-home"])
  }

  // MARK: - Gap 4: leave one of two families

  private func loadTwoFamilies(selecting selected: String) async {
    service.stubbedMemberships = [joinedMembership, homeMembership]
    await manager.loadFamilyData()
    await manager.switchFamily(to: selected)
    management.parentFamilies = [parentFamily("family-joined"), parentFamily("family-home")]
  }

  func test_leavingTheOtherFamily_keepsTheSelectedOneAndDropsTheSwitcher() async {
    await loadTwoFamilies(selecting: "family-home")
    XCTAssertEqual(manager.familyChoices.count, 2)
    let switchesBefore = manager.familySwitchCount

    service.stubbedMemberships = [homeMembership]
    management.confirmLeave(parentFamily("family-joined"))
    await management.leaveFamily()

    XCTAssertEqual(service.leaveCalls.map(\.familyId), ["family-joined"])
    XCTAssertEqual(manager.memberships.map(\.familyUnitId), ["family-home"])
    XCTAssertEqual(manager.familyUnitId, "family-home")
    XCTAssertEqual(manager.selectedAthleteId, "ath-home")
    XCTAssertTrue(manager.familyChoices.count < 2, "the switcher only shows with two or more families")
    XCTAssertEqual(manager.familySwitchCount, switchesBefore, "staying put must not rebuild the views")
  }

  func test_leavingTheSelectedFamily_fallsBackToTheRemainingOneAndRebuildsViews() async {
    await loadTwoFamilies(selecting: "family-joined")
    XCTAssertEqual(manager.familyUnitId, "family-joined")
    let switchesBefore = manager.familySwitchCount

    service.stubbedMemberships = [homeMembership]
    management.confirmLeave(parentFamily("family-joined"))
    await management.leaveFamily()

    XCTAssertEqual(manager.memberships.map(\.familyUnitId), ["family-home"])
    XCTAssertEqual(manager.familyUnitId, "family-home")
    XCTAssertEqual(manager.currentMember?.familyUnitId, "family-home")
    XCTAssertEqual(manager.selectedAthleteId, "ath-home", "the left family's athlete must not stay selected")
    XCTAssertEqual(manager.familyMembers.map(\.familyUnitId), ["family-home", "family-home"])
    XCTAssertTrue(manager.familyChoices.count < 2)
    XCTAssertEqual(manager.familySwitchCount, switchesBefore + 1, "the views rebuild onto the remaining family")
  }

  func test_aSavedSelectionForTheLeftFamilyDoesNotComeBackOnTheNextLoad() async {
    await loadTwoFamilies(selecting: "family-joined")
    service.stubbedMemberships = [homeMembership]
    management.confirmLeave(parentFamily("family-joined"))
    await management.leaveFamily()

    await manager.loadFamilyData()

    XCTAssertEqual(manager.familyUnitId, "family-home")
  }
}
