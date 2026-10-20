import XCTest
@testable import TheRecruitingCompass

final class FamilyUpdateNotificationTests: XCTestCase {
  func test_familyUpdateType_decodesWithFamilyLabel() throws {
    let type = try JSONDecoder().decode(NotificationType.self, from: Data(#""family_update""#.utf8))
    XCTAssertEqual(type, .familyUpdate)
    XCTAssertEqual(type.label, "Family")
  }

  func test_familyUpdate_hasNoPushPreferenceRow() {
    XCTAssertFalse(NotificationType.familyUpdate.hasPushPreference)
    XCTAssertTrue(NotificationType.offer.hasPushPreference)
  }

  func test_familyUpdateRow_decodesAndRoutesToFamilyManagement() throws {
    let json = #"""
    {"id":"n1","user_id":"u1","type":"family_update","title":"Family member left","message":"Gail left Smith.",
     "priority":"normal","action_url":"/settings/family-management","created_at":"2026-10-19T10:00:00Z"}
    """#
    let notification = try JSONDecoder().decode(AppNotification.self, from: Data(json.utf8))

    XCTAssertEqual(notification.type, .familyUpdate)
    XCTAssertEqual(NotificationDestinationParser.destination(from: notification), .familyManagement)
  }
}
