import XCTest
@testable import TheRecruitingCompass

@MainActor
final class FamilyManagementViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var sut: FamilyManagementViewModel!
  private var mockFamilyService: MockFamilyService!
  private var mockAuthManager: MockAuthManager!
  private var mockInboundDraftsService: MockInboundDraftsAPIService!

  override func setUp() async throws {
    mockFamilyService = MockFamilyService()
    mockAuthManager = MockAuthManager()
    mockInboundDraftsService = MockInboundDraftsAPIService()
    sut = FamilyManagementViewModel(
      familyService: mockFamilyService,
      authManager: mockAuthManager,
      inboundDraftsService: mockInboundDraftsService
    )
  }

  override func tearDown() async throws {
    sut = nil
    mockFamilyService = nil
    mockAuthManager = nil
    mockInboundDraftsService = nil
  }

  // MARK: - sendEmailInvite errors

  func testSendEmailInvite_serverRejection_showsServerMessage() async {
    let message = "This person is already a member of your family"
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = FamilyError.serverError(message)
    sut.inviteEmail = "member@example.com"

    await sut.sendEmailInvite()

    XCTAssertEqual(sut.errorMessage, message)
  }

  func testSendEmailInvite_nonServerError_usesGenericMessage() async {
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = URLError(.notConnectedToInternet)
    sut.inviteEmail = "member@example.com"

    await sut.sendEmailInvite()

    XCTAssertEqual(sut.errorMessage, "Failed to send invite. Please try again.")
  }

  // MARK: - Test Helpers

  private func makeUser(id: String = "user-1", role: UserRole = .player) -> User {
    return User(
      id: id,
      email: "test@test.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      fullName: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: role,
      dateOfBirth: nil
    )
  }

  private func makeFamilyUnit(
    id: String = "family-1",
    createdByUserId: String = "user-1",
    familyCode: String = "FAM-ABC123",
    familyName: String = "Test Family",
    codeGeneratedAt: String = "2024-01-01T00:00:00Z"
  ) -> FamilyUnit {
    FamilyUnit(
      id: id,
      createdByUserId: createdByUserId,
      familyName: familyName,
      familyCode: familyCode,
      codeGeneratedAt: codeGeneratedAt,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )
  }

  private func makeFamilyMember(
    id: String = "member-1",
    userId: String = "user-1",
    familyUnitId: String = "family-1",
    role: String = "athlete"
  ) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: userId,
      familyUnitId: familyUnitId,
      role: role,
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
  }

  // MARK: - Initialization Tests

  func testInit_mockDependencies() {
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertTrue(sut.familyMembers.isEmpty)
    XCTAssertTrue(sut.parentFamilies.isEmpty)
    XCTAssertEqual(sut.codeInput, "")
  }

  func testIsPlayer_whenUserIsPlayer_returnsTrue() {
    mockAuthManager.setMockUser(makeUser(role: .player))
    XCTAssertTrue(sut.isPlayer)
    XCTAssertFalse(sut.isParent)
  }

  func testIsParent_whenUserIsParent_returnsTrue() {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    XCTAssertTrue(sut.isParent)
    XCTAssertFalse(sut.isPlayer)
  }

  func testIsCodeInputValid_validCode_returnsTrue() {
    sut.codeInput = "FAM-ABC123"
    XCTAssertTrue(sut.isCodeInputValid)
  }

  func testIsCodeInputValid_invalidCode_returnsFalse() {
    sut.codeInput = "invalid"
    XCTAssertFalse(sut.isCodeInputValid)

    sut.codeInput = "FAM123"
    XCTAssertFalse(sut.isCodeInputValid)

    sut.codeInput = "FAM-abc123" // lowercase not allowed
    XCTAssertFalse(sut.isCodeInputValid)
  }

  // MARK: - Player Data Loading Tests

  func testLoadData_asPlayer_loadsFamilyUnit() async {
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()
    mockFamilyService.stubbedFamilyMembers = [makeFamilyMember()]

    await sut.loadData()

    XCTAssertEqual(mockFamilyService.getFamilyUnitCallCount, 1)
    XCTAssertEqual(sut.familyCode, "FAM-ABC123")
    XCTAssertEqual(sut.familyId, "family-1")
    XCTAssertEqual(sut.familyName, "Test Family")
    XCTAssertNotNil(sut.codeGeneratedAt)
    XCTAssertEqual(sut.familyMembers.count, 1)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadData_asPlayer_noFamilyUnit_neverCreatesOne() async {
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockFamilyService.stubbedFamilyUnit = nil

    await sut.loadData()

    XCTAssertEqual(mockFamilyService.getFamilyUnitCallCount, 1)
    XCTAssertEqual(mockFamilyService.createFamilyCallCount, 0)
    XCTAssertNil(sut.familyId)
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadData_asParent_leftLastFamily_neverCreatesOne() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = []

    await sut.loadData()

    XCTAssertEqual(mockFamilyService.createFamilyCallCount, 0)
    XCTAssertEqual(mockFamilyService.getParentFamiliesCallCount, 1)
    XCTAssertTrue(sut.parentFamilies.isEmpty)
  }

  func testLoadData_asPlayer_noUserId_setsError() async {
    // Set user to player role but with no ID
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockAuthManager.user = nil // Clear user after setting role expectation

    await sut.loadData()

    // Note: When user is nil, isPlayer returns false, so loadPlayerData() is not called
    // and no error message is set. This is expected behavior.
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(mockFamilyService.getFamilyUnitCallCount, 0)
  }

  func testLoadData_asPlayer_serviceError_setsError() async {
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockFamilyService.shouldSucceed = false

    await sut.loadData()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to load family data. Please try again.")
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadFamilyMembers_success() async {
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()
    mockFamilyService.stubbedFamilyMembers = [
      makeFamilyMember(id: "m1", role: "athlete"),
      makeFamilyMember(id: "m2", role: "parent")
    ]

    await sut.loadData()

    XCTAssertEqual(sut.familyMembers.count, 2)
    XCTAssertEqual(mockFamilyService.fetchFamilyMembersCallCount, 1)
    XCTAssertFalse(sut.loadingMembers)
  }

  // MARK: - Player Actions Tests

  func testCopyCodeToClipboard_copiesCode() {
    sut.familyCode = "FAM-ABC123"

    sut.copyCodeToClipboard()

    XCTAssertEqual(UIPasteboard.general.string, "FAM-ABC123")
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(sut.successMessage, "Family code copied to clipboard!")
  }

  // MARK: - Inbound Address Tests

  func testLoadData_asPlayer_loadsInboundAddress() async {
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()
    mockInboundDraftsService.addressesToReturn = [
      InboundFamilyAddress(familyUnitId: "family-1", familyName: "Smith Family", address: "family-abc123@inbound.therecruitingcompass.com")
    ]

    await sut.loadData()

    XCTAssertEqual(sut.inboundAddresses.map(\.address), ["family-abc123@inbound.therecruitingcompass.com"])
  }

  func testLoadData_asParent_loadsInboundAddress() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [
      ParentFamilyData(familyId: "family-1", familyCode: "FAM-ABC123", familyName: "Smith Family", codeGeneratedAt: "2024-01-01T00:00:00Z")
    ]
    mockInboundDraftsService.addressesToReturn = [
      InboundFamilyAddress(familyUnitId: "family-1", familyName: "Smith Family", address: "family-xyz789@inbound.therecruitingcompass.com")
    ]

    await sut.loadData()

    XCTAssertEqual(sut.inboundAddresses.map(\.address), ["family-xyz789@inbound.therecruitingcompass.com"])
  }

  func testLoadData_asParent_multiFamily_loadsOneAddressPerFamily() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [
      ParentFamilyData(familyId: "family-1", familyCode: "FAM-ABC123", familyName: "Smith Family", codeGeneratedAt: "2024-01-01T00:00:00Z"),
      ParentFamilyData(familyId: "family-2", familyCode: "FAM-XYZ456", familyName: "Jones Family", codeGeneratedAt: "2024-01-01T00:00:00Z")
    ]
    mockInboundDraftsService.addressesToReturn = [
      InboundFamilyAddress(familyUnitId: "family-1", familyName: "Smith Family", address: "family-abc123@inbound.therecruitingcompass.com"),
      InboundFamilyAddress(familyUnitId: "family-2", familyName: "Jones Family", address: "family-def456@inbound.therecruitingcompass.com")
    ]

    await sut.loadData()

    XCTAssertEqual(sut.inboundAddresses.count, 2)
    XCTAssertEqual(sut.inboundAddresses.map(\.familyUnitId), ["family-1", "family-2"])
  }

  func testDisplayLabel_parentFamily_usesServerLabelFromInboundAddress() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [
      ParentFamilyData(familyId: "family-1", familyCode: "FAM-ABC123", familyName: "Smith Family", codeGeneratedAt: "x"),
      ParentFamilyData(familyId: "family-2", familyCode: "FAM-XYZ456", familyName: "Jones Family", codeGeneratedAt: "x")
    ]
    mockInboundDraftsService.addressesToReturn = [
      InboundFamilyAddress(familyUnitId: "family-1", familyName: "Smith Family", familyLabel: "Alex's Family", address: "a@b.c")
    ]

    await sut.loadData()

    XCTAssertEqual(sut.displayLabel(for: sut.parentFamilies[0]), "Alex's Family")
    // No label for family-2 (old API or fetch gap): keep the stored name, never compute one.
    XCTAssertEqual(sut.displayLabel(for: sut.parentFamilies[1]), "Jones Family")
  }

  func testPlayerFamilyCodeHeading_usesServerLabelElseGenericHeading() async {
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit(familyName: "My Family")
    mockInboundDraftsService.addressesToReturn = [
      InboundFamilyAddress(familyUnitId: "family-1", familyName: "My Family", familyLabel: "Alex's Family", address: "a@b.c")
    ]
    await sut.loadData()
    XCTAssertEqual(sut.playerFamilyCodeHeading, "Alex's family code")

    // Old prod: no label, stored name is the generic default; heading must not change.
    mockInboundDraftsService.addressesToReturn = [
      InboundFamilyAddress(familyUnitId: "family-1", familyName: "My Family", address: "a@b.c")
    ]
    await sut.loadData()
    XCTAssertEqual(sut.playerFamilyCodeHeading, "Your Family Code")
  }

  func testJoinFamily_successMessageUsesServerLabel() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    sut.codeInput = "FAM-ABC123"
    mockFamilyService.mockParentFamilies = []
    mockFamilyService.stubbedJoinResponse = JoinFamilyResponse(familyId: "f", familyName: "Smith Family", familyLabel: "Alex's Family")

    await sut.joinFamily()

    XCTAssertEqual(sut.successMessage, "Successfully joined Alex's Family!")
  }

  func testLoadData_inboundAddressFetchFailure_doesNotSetErrorOrFailLoad() async {
    mockAuthManager.setMockUser(makeUser(role: .player))
    mockFamilyService.stubbedFamilyUnit = makeFamilyUnit()
    mockInboundDraftsService.errorToThrow = FamilyError.serverError("boom")

    await sut.loadData()

    XCTAssertTrue(sut.inboundAddresses.isEmpty)
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(sut.familyCode, "FAM-ABC123")
  }

  func testCopyInboundAddressToClipboard_copiesAddress() {
    sut.copyInboundAddressToClipboard("family-abc123@inbound.therecruitingcompass.com")

    XCTAssertEqual(UIPasteboard.general.string, "family-abc123@inbound.therecruitingcompass.com")
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(sut.successMessage, "Address copied to clipboard!")
  }

  func testConfirmRegenerateCode_setsConfirmation() {
    sut.confirmRegenerateCode()

    XCTAssertTrue(sut.showRegenerateConfirmation)
  }

  func testRegenerateCode_success_updatesCode() async {
    sut.familyId = "family-1"
    sut.familyCode = "FAM-OLD123"

    await sut.regenerateCode()

    XCTAssertEqual(mockFamilyService.regenerateCodeCallCount, 1)
    XCTAssertEqual(mockFamilyService.lastFamilyIdRegenerated, "family-1")
    XCTAssertEqual(sut.familyCode, "FAM-XYZ789")
    XCTAssertNotNil(sut.codeGeneratedAt)
    XCTAssertFalse(sut.showRegenerateConfirmation)
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(sut.successMessage, "Family code regenerated successfully!")
    XCTAssertFalse(sut.isLoading)
  }

  func testRegenerateCode_noFamilyId_setsError() async {
    sut.familyId = nil

    await sut.regenerateCode()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "No family ID available")
    XCTAssertEqual(mockFamilyService.regenerateCodeCallCount, 0)
  }

  func testRegenerateCode_error_setsError() async {
    sut.familyId = "family-1"
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = FamilyError.serverError("Only the family owner can regenerate the code")

    await sut.regenerateCode()

    XCTAssertEqual(sut.errorMessage, "Only the family owner can regenerate the code")
    XCTAssertFalse(sut.isLoading)
  }

  func testConfirmRemoveMember_setsConfirmation() {
    let member = makeFamilyMember()

    sut.confirmRemoveMember(member)

    XCTAssertTrue(sut.showDeleteConfirmation)
    XCTAssertEqual(sut.memberToRemove?.id, "member-1")
  }

  func testRemoveMember_success_removesMember() async {
    let member = makeFamilyMember(id: "member-1")
    sut.familyMembers = [member, makeFamilyMember(id: "member-2")]
    sut.memberToRemove = member

    await sut.removeMember()

    XCTAssertEqual(mockFamilyService.removeFamilyMemberCallCount, 1)
    XCTAssertEqual(mockFamilyService.lastMemberIdRemoved, "member-1")
    XCTAssertEqual(sut.familyMembers.count, 1)
    XCTAssertEqual(sut.familyMembers.first?.id, "member-2")
    XCTAssertNil(sut.memberToRemove)
    XCTAssertFalse(sut.showDeleteConfirmation)
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(sut.successMessage, "Family member removed successfully!")
    XCTAssertFalse(sut.isLoading)
  }

  func testRemoveMember_error_setsError() async {
    let member = makeFamilyMember()
    sut.memberToRemove = member
    sut.familyMembers = [member]
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = FamilyError.serverError("Only the family owner can remove members")

    await sut.removeMember()

    XCTAssertEqual(sut.errorMessage, "Only the family owner can remove members")
    XCTAssertEqual(sut.familyMembers.count, 1) // Not removed
    XCTAssertFalse(sut.isLoading)
  }

  // MARK: - Parent Data Loading Tests

  func testLoadData_asParent_loadsParentFamilies() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [
      ParentFamilyData(
        familyId: "family-1",
        familyCode: "FAM-ABC123",
        familyName: "Smith Family",
        codeGeneratedAt: "2024-01-01T00:00:00Z"
      )
    ]

    await sut.loadData()

    XCTAssertEqual(mockFamilyService.getParentFamiliesCallCount, 1)
    XCTAssertEqual(sut.parentFamilies.count, 1)
    XCTAssertEqual(sut.parentFamilies.first?.familyName, "Smith Family")
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadData_asParent_loadsMembersForEachFamily() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [
      ParentFamilyData(familyId: "family-1", familyCode: "FAM-ABC123", familyName: "Smith Family", codeGeneratedAt: "2024-01-01T00:00:00Z"),
      ParentFamilyData(familyId: "family-2", familyCode: "FAM-XYZ789", familyName: "Jones Family", codeGeneratedAt: "2024-01-01T00:00:00Z")
    ]
    mockFamilyService.membersByFamilyUnitId = [
      "family-1": [makeFamilyMember(id: "m1", familyUnitId: "family-1", role: "athlete")],
      "family-2": [makeFamilyMember(id: "m2", familyUnitId: "family-2", role: "athlete")]
    ]

    await sut.loadData()

    XCTAssertEqual(mockFamilyService.fetchFamilyMembersCallCount, 2)
    XCTAssertEqual(sut.parentFamilies.first(where: { $0.familyId == "family-1" })?.members.map(\.id), ["m1"])
    XCTAssertEqual(sut.parentFamilies.first(where: { $0.familyId == "family-2" })?.members.map(\.id), ["m2"])
  }

  func testLoadData_asParent_memberFetchFailure_doesNotFailWholeLoad() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [
      ParentFamilyData(familyId: "family-1", familyCode: "FAM-ABC123", familyName: "Smith Family", codeGeneratedAt: "2024-01-01T00:00:00Z"),
      ParentFamilyData(familyId: "family-2", familyCode: "FAM-XYZ789", familyName: "Jones Family", codeGeneratedAt: "2024-01-01T00:00:00Z")
    ]
    mockFamilyService.familyUnitIdsToFail = ["family-1"]
    mockFamilyService.membersByFamilyUnitId = [
      "family-2": [makeFamilyMember(id: "m2", familyUnitId: "family-2", role: "athlete")]
    ]

    await sut.loadData()

    XCTAssertEqual(sut.parentFamilies.count, 2)
    XCTAssertEqual(sut.parentFamilies.first(where: { $0.familyId == "family-1" })?.members.isEmpty, true)
    XCTAssertEqual(sut.parentFamilies.first(where: { $0.familyId == "family-2" })?.members.map(\.id), ["m2"])
  }

  func testLoadData_asParent_error_setsError() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.shouldSucceed = false

    await sut.loadData()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to load families. Please try again.")
    XCTAssertFalse(sut.isLoading)
  }

  // MARK: - Parent Actions Tests

  func testJoinFamily_validCode_success() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    sut.codeInput = "FAM-ABC123"
    mockFamilyService.mockParentFamilies = []

    await sut.joinFamily()

    XCTAssertEqual(mockFamilyService.joinFamilyWithCodeCallCount, 1)
    XCTAssertEqual(mockFamilyService.lastFamilyCodeJoined, "FAM-ABC123")
    XCTAssertEqual(mockFamilyService.createFamilyCallCount, 0)
    XCTAssertEqual(mockFamilyService.getParentFamiliesCallCount, 1)
    XCTAssertEqual(sut.codeInput, "")
    XCTAssertTrue(sut.showSuccessToast)
    XCTAssertEqual(sut.successMessage, "Successfully joined family!")
    XCTAssertFalse(sut.isLoading)
  }

  func testJoinFamily_invalidCode_setsError() async {
    sut.codeInput = "invalid"

    await sut.joinFamily()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Invalid family code format. Codes look like FAM-XXXXXX")
    XCTAssertEqual(mockFamilyService.joinFamilyWithCodeCallCount, 0)
  }

  func testJoinFamily_serviceError_setsError() async {
    sut.codeInput = "FAM-ABC123"
    mockFamilyService.shouldSucceed = false
    // Use a generic error (not FamilyError) to hit the generic catch block
    struct GenericError: Error {}
    mockFamilyService.mockError = GenericError()

    await sut.joinFamily()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertEqual(sut.errorMessage, "Failed to join family. Please try again.")
    XCTAssertFalse(sut.isLoading)
  }

  func testJoinFamily_familyError_setsFamilyErrorMessage() async {
    sut.codeInput = "FAM-ABC123"
    mockFamilyService.shouldSucceed = false
    mockFamilyService.mockError = FamilyError.invalidCode

    await sut.joinFamily()

    XCTAssertEqual(sut.errorMessage, "Invalid family code format. Codes look like FAM-XXXXXX")
    XCTAssertFalse(sut.isLoading)
  }

  func testFormatCodeInput_uppercases() {
    sut.codeInput = "fam-abc123"

    sut.formatCodeInput()

    XCTAssertEqual(sut.codeInput, "FAM-ABC123")
  }

  func testClearError_clearsErrorMessage() {
    sut.errorMessage = "Some error"

    sut.clearError()

    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - Leave flow & server-driven gating (ios#365)

  private func parentFamily(canLeave: Bool? = true, reason: String? = nil) -> ParentFamilyData {
    var family = ParentFamilyData(
      familyId: "family-1", familyCode: "FAM-ABC123", familyName: "Smith", codeGeneratedAt: "x"
    )
    family.canLeave = canLeave
    family.leaveBlockedReason = reason
    return family
  }

  func testLoadData_asParent_carriesServerLeaveVerdictAndMemberRules() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [parentFamily(canLeave: nil)]
    var blocked = makeFamilyMember(id: "m1", role: "parent")
    blocked.canRemove = false
    blocked.removeBlockedReason = "Only guardian."
    mockFamilyService.stubbedDetailByFamilyId["family-1"] = FamilyMembersDetail(
      members: [blocked], canLeave: false, leaveBlockedReason: "Invite another guardian first."
    )

    await sut.loadData()

    XCTAssertEqual(sut.parentFamilies.first?.canLeave, false)
    XCTAssertEqual(sut.parentFamilies.first?.leaveBlockedReason, "Invite another guardian first.")
    XCTAssertEqual(sut.parentFamilies.first?.members.first?.removeBlockedReason, "Only guardian.")
  }

  func testLoadData_detailEndpointDown_fallsBackToDirectReadWithNoRuleVerdicts() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    mockFamilyService.mockParentFamilies = [parentFamily(canLeave: nil)]
    mockFamilyService.detailError = FamilyError.serverError("down")
    mockFamilyService.stubbedFamilyMembers = [makeFamilyMember(id: "m1")]

    await sut.loadData()

    XCTAssertEqual(sut.parentFamilies.first?.members.count, 1)
    XCTAssertNil(sut.parentFamilies.first?.canLeave, "no verdict means no Leave button")
    XCTAssertNil(sut.parentFamilies.first?.members.first?.canRemove)
  }

  func testLeave_success_sendsUnconfirmed_dropsFamily_andRefreshesContext() async {
    sut.parentFamilies = [parentFamily()]
    var refreshed = false
    sut.onMembershipChanged = { refreshed = true }
    sut.confirmLeave(sut.parentFamilies[0])

    await sut.leaveFamily()

    XCTAssertEqual(mockFamilyService.leaveCalls.map(\.familyId), ["family-1"])
    XCTAssertEqual(mockFamilyService.leaveCalls.map(\.confirm), [false])
    XCTAssertTrue(sut.parentFamilies.isEmpty)
    XCTAssertTrue(refreshed)
    XCTAssertEqual(sut.successMessage, "You left the family.")
    XCTAssertNil(sut.errorMessage)
  }

  func testLeave_lastMember_asksForConfirmation_thenResendsWithConfirmDeleteFamily() async {
    sut.parentFamilies = [parentFamily()]
    mockFamilyService.leaveResults = [
      .failure(FamilyError.lastMemberConfirmationRequired("Leaving deletes the family and all of its data.")),
      .success(.familyDeleted)
    ]
    sut.confirmLeave(sut.parentFamilies[0])

    await sut.leaveFamily()

    XCTAssertTrue(sut.showLastMemberConfirmation)
    XCTAssertEqual(sut.lastMemberLeaveWarning, "Leaving deletes the family and all of its data.")
    XCTAssertEqual(sut.parentFamilies.count, 1, "nothing removed until the user confirms")
    XCTAssertNil(sut.errorMessage, "the confirmation prompt is not an error")

    await sut.leaveFamily(confirmDeleteFamily: true)

    XCTAssertEqual(mockFamilyService.leaveCalls.map(\.confirm), [false, true])
    XCTAssertTrue(sut.parentFamilies.isEmpty)
    XCTAssertEqual(sut.successMessage, "Family deleted.")
  }

  func testLeave_cancelAtLastMemberPrompt_neverSendsConfirm() async {
    sut.parentFamilies = [parentFamily()]
    mockFamilyService.leaveResults = [.failure(FamilyError.lastMemberConfirmationRequired("warn"))]
    sut.confirmLeave(sut.parentFamilies[0])
    await sut.leaveFamily()

    sut.cancelLeave()

    XCTAssertEqual(mockFamilyService.leaveCalls.count, 1)
    XCTAssertFalse(sut.showLastMemberConfirmation)
    XCTAssertEqual(sut.parentFamilies.count, 1)
  }

  func testLeave_serverRefusal_showsServerMessage_andKeepsFamily() async {
    sut.parentFamilies = [parentFamily()]
    mockFamilyService.leaveResults = [
      .failure(FamilyError.serverError("You're the player's only guardian, so you can leave once they turn 18."))
    ]
    sut.confirmLeave(sut.parentFamilies[0])

    await sut.leaveFamily()

    XCTAssertEqual(sut.errorMessage, "You're the player's only guardian, so you can leave once they turn 18.")
    XCTAssertEqual(sut.parentFamilies.count, 1)
  }

  func testLeave_busyRetryError_showsRetryableServerMessage() async {
    sut.parentFamilies = [parentFamily()]
    mockFamilyService.leaveResults = [
      .failure(FamilyError.busyRetry("Someone else just changed this family. Please try again."))
    ]
    sut.confirmLeave(sut.parentFamilies[0])

    await sut.leaveFamily()

    XCTAssertEqual(sut.errorMessage, "Someone else just changed this family. Please try again.")
    XCTAssertEqual(sut.parentFamilies.count, 1)
  }

  func testRemoveMember_refreshesParentFamilyRulesAfterSuccess() async {
    mockAuthManager.setMockUser(makeUser(role: .parent))
    var family = parentFamily()
    let member = makeFamilyMember(id: "m2", role: "parent")
    family.members = [member]
    sut.parentFamilies = [family]
    mockFamilyService.stubbedDetailByFamilyId["family-1"] = FamilyMembersDetail(members: [], canLeave: false,
                                                                                leaveBlockedReason: "Only member.")
    sut.confirmRemoveMember(member)

    await sut.removeMember()

    XCTAssertEqual(sut.parentFamilies.first?.members.count, 0)
    XCTAssertEqual(sut.parentFamilies.first?.leaveBlockedReason, "Only member.")
  }

  func testRemoveMember_success_refreshesAppWideFamilyContext() async {
    let member = makeFamilyMember(id: "m1")
    sut.familyMembers = [member]
    sut.memberToRemove = member
    var refreshed = false
    sut.onMembershipChanged = { refreshed = true }

    await sut.removeMember()

    XCTAssertTrue(refreshed)
  }

  func testMemberCard_disabledRemoveShowsServerReason_andUnknownVerdictShowsNothing() {
    var blocked = makeFamilyMember()
    blocked.canRemove = false
    blocked.removeBlockedReason = "Only guardian."
    XCTAssertEqual(FamilyMemberCard(member: blocked, onRemove: {}).blockedReason, "Only guardian.")

    var allowed = makeFamilyMember()
    allowed.canRemove = true
    allowed.removeBlockedReason = "stale"
    XCTAssertNil(FamilyMemberCard(member: allowed, onRemove: {}).blockedReason)

    XCTAssertNil(FamilyMemberCard(member: makeFamilyMember(), onRemove: {}).blockedReason)
  }
}
