import XCTest
@testable import TheRecruitingCompass

@MainActor
final class FamilyManagementViewModelResendTests: XCTestCase {
  nonisolated deinit {}

  func testResendInvitation_sendsTheInvitationsFamily_notTheSelectedOne() async {
    let service = MockFamilyService()
    let sut = FamilyManagementViewModel(
      familyService: service,
      authManager: MockAuthManager(),
      inboundDraftsService: MockInboundDraftsAPIService()
    )
    sut.selectedFamilyId = "family-B"
    let invitation = FamilyInvitation(
      id: "i1", familyUnitId: "family-A", invitedBy: nil, invitedEmail: "gran@example.com", role: "parent",
      token: nil, status: "pending", expiresAt: nil, createdAt: nil, acceptedAt: nil, declinedAt: nil
    )

    await sut.resendInvitation(invitation)

    XCTAssertEqual(service.lastResendFamilyUnitId, "family-A")
  }
}
