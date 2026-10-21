import XCTest
@testable import TheRecruitingCompass

@MainActor
final class FamilySetupViewModelTests: XCTestCase {
  nonisolated deinit {}

  private var service: MockFamilyService!
  private var auth: MockAuthManager!
  private var membershipChanges = 0

  override func setUp() {
    service = MockFamilyService()
    auth = MockAuthManager()
    membershipChanges = 0
    auth.setMockUser(User(
      id: "u1", email: "Kid@Example.com", emailConfirmedAt: nil,
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", role: .player
    ))
  }

  private func makeSut() -> FamilySetupViewModel {
    FamilySetupViewModel(familyService: service, authManager: auth) { [unowned self] in membershipChanges += 1 }
  }

  private func pendingInvite(email: String = "kid@example.com") -> FamilyInvitation {
    FamilyInvitation(
      id: "i1", familyUnitId: "f1", invitedBy: "u9", invitedEmail: email, role: "player", token: nil,
      status: "pending", expiresAt: "2999-01-01T00:00:00+00:00", createdAt: nil, acceptedAt: nil, declinedAt: nil
    )
  }

  func test_noInvite_offersCreate_andCreateRunsOnlyOnTap() async {
    let sut = makeSut()
    await sut.checkForPendingInvite()
    XCTAssertTrue(sut.offersCreate)
    XCTAssertEqual(service.createFamilyCallCount, 0)

    await sut.createFamily()

    XCTAssertEqual(service.createFamilyCallCount, 1)
    XCTAssertEqual(service.lastCreatedFamilyRole, .player)
    XCTAssertEqual(membershipChanges, 1)
  }

  func test_pendingInvite_hidesCreate_andNeverCallsTheCreateEndpoint() async {
    service.stubbedAddressedInvitations = [pendingInvite()]
    let sut = makeSut()
    await sut.checkForPendingInvite()

    XCTAssertFalse(sut.offersCreate)
    await sut.createFamily()

    XCTAssertEqual(service.createFamilyCallCount, 0)
    XCTAssertEqual(service.lastAddressedEmail, "Kid@Example.com")
  }

  func test_pendingInvite_stillAllowsJoinByCode() async {
    service.stubbedAddressedInvitations = [pendingInvite()]
    let sut = makeSut()
    await sut.checkForPendingInvite()
    sut.familyCode = " fam-abc123 "

    await sut.joinWithCode()

    XCTAssertEqual(service.lastFamilyCodeJoined, "FAM-ABC123")
    XCTAssertEqual(membershipChanges, 1)
    XCTAssertNil(sut.errorMessage)
  }

  func test_expiredInvite_returnsToOfferingCreate() async {
    let expired = FamilyInvitation(
      id: "i1", familyUnitId: "f1", invitedBy: "u9", invitedEmail: "kid@example.com", role: "player", token: nil,
      status: "pending", expiresAt: "2001-01-01T00:00:00+00:00", createdAt: nil, acceptedAt: nil, declinedAt: nil
    )
    service.stubbedAddressedInvitations = [expired]
    let sut = makeSut()

    await sut.checkForPendingInvite()

    XCTAssertTrue(sut.offersCreate)
  }

  func test_inviteLookupFailure_fallsBackToCreate() async {
    service.addressedInvitationsError = FamilyError.serverError("boom")
    let sut = makeSut()

    await sut.checkForPendingInvite()

    XCTAssertTrue(sut.offersCreate)
    XCTAssertFalse(sut.isChecking)
  }

  func test_invalidCode_isRejectedWithoutARequest() async {
    let sut = makeSut()
    sut.familyCode = "nope"

    await sut.joinWithCode()

    XCTAssertEqual(service.joinFamilyWithCodeCallCount, 0)
    XCTAssertNotNil(sut.errorMessage)
  }

  func test_create409_isHandledGracefully_andRechecksMembershipAndInvites() async {
    service.shouldSucceed = false
    service.mockError = FamilyError.createConflict
    let sut = makeSut()
    await sut.checkForPendingInvite()
    service.stubbedAddressedInvitations = [pendingInvite()]

    await sut.createFamily()

    XCTAssertEqual(sut.errorMessage, FamilyError.createConflict.errorDescription)
    XCTAssertEqual(membershipChanges, 1)
    XCTAssertFalse(sut.offersCreate)
    XCTAssertFalse(sut.isSubmitting)
  }

  func test_createFailure_showsTheServerMessage_andDoesNotAdmitTheUser() async {
    service.shouldSucceed = false
    service.mockError = FamilyError.serverError("Failed to create family")
    let sut = makeSut()

    await sut.createFamily()

    XCTAssertEqual(sut.errorMessage, "Failed to create family")
    XCTAssertEqual(membershipChanges, 0)
  }
}
