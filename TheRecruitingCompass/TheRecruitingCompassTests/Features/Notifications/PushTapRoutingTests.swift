import XCTest
@testable import TheRecruitingCompass

final class PushTapRoutingTests: XCTestCase {
  private func familyRow(actionUrl: String?) throws -> AppNotification {
    let url = actionUrl.map { #","action_url":"\#($0)""# } ?? ""
    let json = #"{"id":"n1","type":"family_update","title":"t","created_at":"2026-10-19T10:00:00Z"\#(url)}"#
    return try JSONDecoder().decode(AppNotification.self, from: Data(json.utf8))
  }

  func test_payloadWithOnlyNotificationId_looksUpRowAndRoutesByActionUrl() async throws {
    let row = try familyRow(actionUrl: "/settings/family-management")
    nonisolated(unsafe) var requested: String?

    let destination = await NotificationDestinationParser.resolveDestination(
      fromPayload: ["notification_id": "n1"],
      fetchNotification: { requested = $0; return row }
    )

    XCTAssertEqual(destination, .familyManagement)
    XCTAssertEqual(requested, "n1")
  }

  func test_payloadWithRelatedEntity_routesWithoutLookup() async {
    nonisolated(unsafe) var fetched = false

    let destination = await NotificationDestinationParser.resolveDestination(
      fromPayload: ["notification_id": "n1", "related_entity_type": "school", "related_entity_id": "s1"],
      fetchNotification: { _ in fetched = true; return nil }
    )

    XCTAssertEqual(destination, .schoolDetail(id: "s1"))
    XCTAssertFalse(fetched)
  }

  func test_rowMissingOrUnroutable_opensNotificationsList() async throws {
    let unroutable = try familyRow(actionUrl: nil)
    let missing = await NotificationDestinationParser.resolveDestination(
      fromPayload: ["notification_id": "n1"], fetchNotification: { _ in nil }
    )
    let noUrl = await NotificationDestinationParser.resolveDestination(
      fromPayload: ["notification_id": "n1"], fetchNotification: { _ in unroutable }
    )

    XCTAssertEqual(missing, .notificationsList)
    XCTAssertEqual(noUrl, .notificationsList)
  }

  func test_payloadWithoutNotificationId_opensNotificationsListWithoutLookup() async {
    nonisolated(unsafe) var fetched = false

    let destination = await NotificationDestinationParser.resolveDestination(
      fromPayload: ["aps": ["alert": "x"]], fetchNotification: { _ in fetched = true; return nil }
    )

    XCTAssertEqual(destination, .notificationsList)
    XCTAssertFalse(fetched)
  }
}
