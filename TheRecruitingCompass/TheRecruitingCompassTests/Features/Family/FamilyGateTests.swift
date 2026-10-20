import XCTest
@testable import TheRecruitingCompass

/// Pins the #396 Must-nevers: loading is not "no family", and an invited user is never offered a solo family.
final class FamilyGateTests: XCTestCase {
  private let now = ISO8601DateFormatter().date(from: "2026-10-20T12:00:00Z")!

  private func invitation(
    email: String = "kid@example.com", status: String = "pending", expiresAt: String? = "2026-10-27T12:00:00+00:00"
  ) -> FamilyInvitation {
    FamilyInvitation(
      id: "i1", familyUnitId: "f1", invitedBy: "u9", invitedEmail: email, role: "player", token: nil,
      status: status, expiresAt: expiresAt, createdAt: nil, acceptedAt: nil, declinedAt: nil
    )
  }

  // MARK: - Route

  func test_loading_isNeverTheGate() {
    XCTAssertEqual(FamilyGate.route(for: .unknown), .loading)
  }

  func test_member_passesThrough() {
    XCTAssertEqual(FamilyGate.route(for: .member), .passThrough)
  }

  func test_onlyAConfirmedZeroMembershipRoutesToSetup() {
    XCTAssertEqual(FamilyGate.route(for: .none), .setup)
  }

  func test_failedRead_failsClosedToRetry_neverTheDashboard() {
    XCTAssertEqual(FamilyGate.route(for: .failed), .retry)
  }

  func test_readResult_mapsFamilyPresence() {
    XCTAssertEqual(FamilyGate.status(afterReading: "f1"), .member)
    XCTAssertEqual(FamilyGate.status(afterReading: nil), .none)
  }

  func test_failedRefresh_keepsAKnownMember_butFailsAFirstRead() {
    XCTAssertEqual(FamilyGate.status(afterFailedReadFrom: .member), .member)
    XCTAssertEqual(FamilyGate.status(afterFailedReadFrom: .unknown), .failed)
    XCTAssertEqual(FamilyGate.status(afterFailedReadFrom: .none), .failed)
  }

  // MARK: - Pending invite

  func test_noInvitations_offersCreate() {
    XCTAssertTrue(FamilyGate.offersCreate(invitations: [], email: "kid@example.com", now: now))
  }

  func test_validPendingInvite_hidesCreate() {
    XCTAssertFalse(FamilyGate.offersCreate(invitations: [invitation()], email: "kid@example.com", now: now))
  }

  func test_emailMatchIsCaseInsensitive() {
    let invitations = [invitation(email: "kid@example.com")]
    XCTAssertFalse(FamilyGate.offersCreate(invitations: invitations, email: "Kid@Example.COM", now: now))
  }

  func test_expiredInvite_offersCreateAgain() {
    let expired = invitation(expiresAt: "2026-10-19T12:00:00+00:00")
    XCTAssertTrue(FamilyGate.offersCreate(invitations: [expired], email: "kid@example.com", now: now))
  }

  func test_fractionalSecondExpiry_isParsed() {
    let expired = invitation(expiresAt: "2026-10-19T12:00:00.123456+00:00")
    let live = invitation(expiresAt: "2026-10-27T12:00:00.123456+00:00")
    XCTAssertTrue(FamilyGate.offersCreate(invitations: [expired], email: "kid@example.com", now: now))
    XCTAssertFalse(FamilyGate.offersCreate(invitations: [live], email: "kid@example.com", now: now))
  }

  func test_acceptedOrDeclinedInvite_offersCreateAgain() {
    for status in ["accepted", "declined"] {
      let settled = invitation(status: status)
      XCTAssertTrue(FamilyGate.offersCreate(invitations: [settled], email: "kid@example.com", now: now), status)
    }
  }

  func test_someoneElsesInvite_doesNotHideCreate() {
    let other = invitation(email: "sibling@example.com")
    XCTAssertTrue(FamilyGate.offersCreate(invitations: [other], email: "kid@example.com", now: now))
  }

  func test_unknownEmail_neverMatches() {
    XCTAssertTrue(FamilyGate.validPendingInvitations([invitation()], email: nil, now: now).isEmpty)
  }
}
