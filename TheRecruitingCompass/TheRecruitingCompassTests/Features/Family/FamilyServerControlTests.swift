import XCTest
@testable import TheRecruitingCompass

/// Pins the Must-never rule: Remove/Leave are enabled only by the server's verdict.
final class FamilyServerControlTests: XCTestCase {
  private func member(canRemove: Bool?, reason: String? = nil) -> FamilyMember {
    FamilyMember(
      id: "m1", userId: "u1", familyUnitId: "f1", role: "parent", addedAt: nil, user: nil,
      canRemove: canRemove, removeBlockedReason: reason
    )
  }

  private func family(canLeave: Bool?, reason: String? = nil) -> ParentFamilyData {
    var family = ParentFamilyData(familyId: "f1", familyCode: "FAM-ABC123", familyName: "S", codeGeneratedAt: "x")
    family.canLeave = canLeave
    family.leaveBlockedReason = reason
    return family
  }

  func test_removeControl_followsServerVerdictOnly() {
    let allowed = FamilyMemberCard(member: member(canRemove: true, reason: "stale"), onRemove: {}).removeControl
    XCTAssertTrue(allowed.isEnabled)
    XCTAssertTrue(allowed.isVisible)
    XCTAssertNil(allowed.reason)

    let blocked = FamilyMemberCard(member: member(canRemove: false, reason: "Only guardian."), onRemove: {}).removeControl
    XCTAssertFalse(blocked.isEnabled, "a blocked member must never be removable")
    XCTAssertTrue(blocked.isVisible)
    XCTAssertEqual(blocked.reason, "Only guardian.")

    let deniedSilently = FamilyMemberCard(member: member(canRemove: false), onRemove: {}).removeControl
    XCTAssertFalse(deniedSilently.isEnabled)
    XCTAssertFalse(deniedSilently.isVisible)

    let unknown = FamilyMemberCard(member: member(canRemove: nil), onRemove: {}).removeControl
    XCTAssertFalse(unknown.isEnabled, "no verdict means not allowed")
    XCTAssertFalse(unknown.isVisible)
  }

  func test_leaveControl_followsServerVerdictOnly() {
    XCTAssertTrue(family(canLeave: true).leaveControl.isEnabled)

    let blocked = family(canLeave: false, reason: "Invite another guardian first.").leaveControl
    XCTAssertFalse(blocked.isEnabled)
    XCTAssertTrue(blocked.isVisible)
    XCTAssertEqual(blocked.reason, "Invite another guardian first.")

    XCTAssertFalse(family(canLeave: nil).leaveControl.isEnabled)
    XCTAssertFalse(family(canLeave: nil).leaveControl.isVisible)
    XCTAssertFalse(family(canLeave: false).leaveControl.isVisible)
  }
}
