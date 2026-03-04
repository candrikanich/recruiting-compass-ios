import XCTest
@testable import TheRecruitingCompass

@MainActor
final class AppNotificationTests: XCTestCase {

  // MARK: - Codable Tests

  func testDecodingFromJSON() {
    let json = """
    {
        "id": "123",
        "user_id": "user-456",
        "type": "follow_up_reminder",
        "title": "Follow up with Coach Smith",
        "message": "It's been 3 days since your last interaction",
        "priority": "high",
        "read_at": null,
        "scheduled_for": "2026-02-15T10:00:00Z",
        "sent_at": null,
        "email_sent": false,
        "email_sent_at": null,
        "action_url": "/coaches?highlight=789",
        "related_entity_type": "coach",
        "related_entity_id": "789",
        "related_school_id": null,
        "related_coach_id": "789",
        "related_offer_id": null,
        "related_event_id": null,
        "created_at": "2026-02-14T10:00:00Z",
        "updated_at": "2026-02-14T10:00:00Z"
    }
    """.data(using: .utf8)!

    let notification = try? JSONDecoder().decode(AppNotification.self, from: json)

    XCTAssertNotNil(notification)
    XCTAssertEqual(notification?.id, "123")
    XCTAssertEqual(notification?.userId, "user-456")
    XCTAssertEqual(notification?.title, "Follow up with Coach Smith")
    XCTAssertEqual(notification?.message, "It's been 3 days since your last interaction")
    XCTAssertEqual(notification?.type, .followUpReminder)
    XCTAssertEqual(notification?.priority, .high)
    XCTAssertFalse(notification?.isRead ?? true)
    XCTAssertEqual(notification?.actionUrl, "/coaches?highlight=789")
    XCTAssertEqual(notification?.relatedEntityType, "coach")
    XCTAssertEqual(notification?.relatedEntityId, "789")
    XCTAssertEqual(notification?.relatedCoachId, "789")
    XCTAssertNil(notification?.relatedSchoolId)
    XCTAssertNil(notification?.relatedOfferId)
    XCTAssertNil(notification?.relatedEventId)
    XCTAssertEqual(notification?.createdAt, "2026-02-14T10:00:00Z")
    XCTAssertEqual(notification?.updatedAt, "2026-02-14T10:00:00Z")
  }

  func testEncodesAndDecodes() throws {
    // Given
    let original = makeNotification(id: "round-trip-1")

    // When
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AppNotification.self, from: encoded)

    // Then
    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.type, original.type)
    XCTAssertEqual(decoded.title, original.title)
    XCTAssertEqual(decoded.message, original.message)
    XCTAssertEqual(decoded.priority, original.priority)
    XCTAssertEqual(decoded.isRead, original.isRead)
    XCTAssertEqual(decoded.scheduledFor, original.scheduledFor)
  }

  func testDecodingWithNilOptionalFields() throws {
    // Given - minimal JSON with only required fields
    let json = """
    {
        "id": "minimal-1",
        "type": "daily_digest",
        "title": "Daily Digest",
        "message": "Here is your daily summary",
        "priority": "low",
        "scheduled_for": "2026-02-15T08:00:00Z"
    }
    """.data(using: .utf8)!

    // When
    let notification = try JSONDecoder().decode(AppNotification.self, from: json)

    // Then
    XCTAssertEqual(notification.id, "minimal-1")
    XCTAssertNil(notification.userId)
    XCTAssertNil(notification.readAt)
    XCTAssertNil(notification.sentAt)
    XCTAssertNil(notification.emailSent)
    XCTAssertNil(notification.emailSentAt)
    XCTAssertNil(notification.actionUrl)
    XCTAssertNil(notification.relatedEntityType)
    XCTAssertNil(notification.relatedEntityId)
    XCTAssertNil(notification.relatedSchoolId)
    XCTAssertNil(notification.relatedCoachId)
    XCTAssertNil(notification.relatedOfferId)
    XCTAssertNil(notification.relatedEventId)
    XCTAssertNil(notification.createdAt)
    XCTAssertNil(notification.updatedAt)
  }

  func testDecodingWithAllFieldsPopulated() throws {
    // Given
    let json = """
    {
        "id": "full-1",
        "user_id": "user-1",
        "type": "offer",
        "title": "New Offer",
        "message": "Stanford made you an offer",
        "priority": "high",
        "read_at": "2026-02-15T12:00:00Z",
        "scheduled_for": "2026-02-15T10:00:00Z",
        "sent_at": "2026-02-15T10:00:00Z",
        "email_sent": true,
        "email_sent_at": "2026-02-15T10:01:00Z",
        "action_url": "/offers/offer-1",
        "related_entity_type": "offer",
        "related_entity_id": "offer-1",
        "related_school_id": "school-1",
        "related_coach_id": "coach-1",
        "related_offer_id": "offer-1",
        "related_event_id": null,
        "created_at": "2026-02-15T09:00:00Z",
        "updated_at": "2026-02-15T12:00:00Z"
    }
    """.data(using: .utf8)!

    // When
    let notification = try JSONDecoder().decode(AppNotification.self, from: json)

    // Then
    XCTAssertEqual(notification.id, "full-1")
    XCTAssertTrue(notification.isRead)
    XCTAssertEqual(notification.emailSent, true)
    XCTAssertEqual(notification.relatedSchoolId, "school-1")
    XCTAssertEqual(notification.relatedOfferId, "offer-1")
  }

  // MARK: - isRead Computed Property Tests

  func testIsReadComputedProperty() {
    let unread = makeNotification(id: "1", readAt: nil)
    XCTAssertFalse(unread.isRead)

    let read = makeNotification(id: "2", readAt: "2026-02-15T09:00:00Z")
    XCTAssertTrue(read.isRead)
  }

  func testIsRead_WithEmptyStringReadAt() {
    // readAt is a non-nil empty string -- isRead should still be true since readAt != nil
    let notification = makeNotification(id: "1", readAt: "")
    XCTAssertTrue(notification.isRead)
  }

  // MARK: - Identifiable Tests

  func testIdentifiable_UniqueIds() {
    let notif1 = makeNotification(id: "unique-1")
    let notif2 = makeNotification(id: "unique-2")

    XCTAssertNotEqual(notif1.id, notif2.id)
    XCTAssertEqual(notif1.id, "unique-1")
  }

  // MARK: - NotificationType Tests

  func testNotificationTypeLabels() {
    XCTAssertEqual(NotificationType.followUpReminder.label, "Follow-ups")
    XCTAssertEqual(NotificationType.deadlineAlert.label, "Deadlines")
    XCTAssertEqual(NotificationType.dailyDigest.label, "Digest")
    XCTAssertEqual(NotificationType.inboundInteraction.label, "Inbound")
    XCTAssertEqual(NotificationType.offer.label, "Offers")
    XCTAssertEqual(NotificationType.event.label, "Events")
  }

  func testNotificationTypeRawValues() {
    XCTAssertEqual(NotificationType.followUpReminder.rawValue, "follow_up_reminder")
    XCTAssertEqual(NotificationType.deadlineAlert.rawValue, "deadline_alert")
    XCTAssertEqual(NotificationType.dailyDigest.rawValue, "daily_digest")
    XCTAssertEqual(NotificationType.inboundInteraction.rawValue, "inbound_interaction")
    XCTAssertEqual(NotificationType.offer.rawValue, "offer")
    XCTAssertEqual(NotificationType.event.rawValue, "event")
  }

  func testNotificationTypeEmojis() {
    for type in NotificationType.allCases {
      XCTAssertFalse(type.emoji.isEmpty, "Emoji should not be empty for \(type.rawValue)")
    }
  }

  func testNotificationType_CaseIterable() {
    XCTAssertEqual(NotificationType.allCases.count, 7) // 6 known + .unknown
  }

  func testDecodingAllNotificationTypes() {
    for type in NotificationType.allCases {
      let json = """
      {
          "id": "1",
          "type": "\(type.rawValue)",
          "title": "Test",
          "message": "Test",
          "priority": "normal",
          "scheduled_for": "2026-02-15T10:00:00Z"
      }
      """.data(using: .utf8)!

      let notification = try? JSONDecoder().decode(AppNotification.self, from: json)
      XCTAssertNotNil(notification, "Failed to decode type: \(type.rawValue)")
      XCTAssertEqual(notification?.type, type)
    }
  }

  // MARK: - NotificationPriority Tests

  func testNotificationPriorityRawValues() {
    XCTAssertEqual(NotificationPriority.low.rawValue, "low")
    XCTAssertEqual(NotificationPriority.normal.rawValue, "normal")
    XCTAssertEqual(NotificationPriority.high.rawValue, "high")
  }

  func testDecodingAllPriorities() {
    for priority in ["low", "normal", "high"] {
      let json = """
      {
          "id": "1",
          "type": "offer",
          "title": "Test",
          "message": "Test",
          "priority": "\(priority)",
          "scheduled_for": "2026-02-15T10:00:00Z"
      }
      """.data(using: .utf8)!

      let notification = try? JSONDecoder().decode(AppNotification.self, from: json)
      XCTAssertNotNil(notification, "Failed to decode priority: \(priority)")
      XCTAssertEqual(notification?.priority.rawValue, priority)
    }
  }

  // MARK: - NotificationDestination Tests

  func testNotificationDestination_Hashable() {
    let dest1 = NotificationDestination.coachDetail(id: "coach-1")
    let dest2 = NotificationDestination.coachDetail(id: "coach-1")
    let dest3 = NotificationDestination.schoolDetail(id: "school-1")

    XCTAssertEqual(dest1, dest2)
    XCTAssertNotEqual(dest1, dest3)
  }

  func testNotificationDestination_AllCases() {
    let destinations: [NotificationDestination] = [
      .coachDetail(id: "c1"),
      .schoolDetail(id: "s1"),
      .interactionDetail(id: "i1"),
      .offerDetail(id: "o1"),
      .eventDetail(id: "e1")
    ]

    // Each should be unique
    let uniqueCount = Set(destinations).count
    XCTAssertEqual(uniqueCount, 5)
  }

  func testNotificationDestination_SetStorage() {
    var destinations: Set<NotificationDestination> = []
    destinations.insert(.coachDetail(id: "c1"))
    destinations.insert(.coachDetail(id: "c1"))
    destinations.insert(.schoolDetail(id: "s1"))

    XCTAssertEqual(destinations.count, 2)
  }

  // MARK: - Edge Cases

  func testSpecialCharactersInTitle() throws {
    let json = """
    {
        "id": "special-1",
        "type": "offer",
        "title": "Coach O'Brien sent an email & <update>",
        "message": "Unicode test: \u{2764}\u{FE0F}",
        "priority": "normal",
        "scheduled_for": "2026-02-15T10:00:00Z"
    }
    """.data(using: .utf8)!

    let notification = try JSONDecoder().decode(AppNotification.self, from: json)
    XCTAssertTrue(notification.title.contains("O'Brien"))
    XCTAssertTrue(notification.title.contains("&"))
  }

  func testEmptyTitle() {
    let notification = makeNotification(id: "1", title: "")
    XCTAssertTrue(notification.title.isEmpty)
  }

  func testLongMessage() {
    let longMessage = String(repeating: "A", count: 5000)
    let notification = makeNotification(id: "1", message: longMessage)
    XCTAssertEqual(notification.message.count, 5000)
  }

  func testInvalidTypeFailsDecoding() {
    let json = """
    {
        "id": "1",
        "type": "invalid_type",
        "title": "Test",
        "message": "Test",
        "priority": "normal",
        "scheduled_for": "2026-02-15T10:00:00Z"
    }
    """.data(using: .utf8)!

    let notification = try? JSONDecoder().decode(AppNotification.self, from: json)
    XCTAssertNotNil(notification)
    XCTAssertEqual(notification?.type, .unknown)
  }

  func testInvalidPriorityFailsDecoding() {
    let json = """
    {
        "id": "1",
        "type": "offer",
        "title": "Test",
        "message": "Test",
        "priority": "critical",
        "scheduled_for": "2026-02-15T10:00:00Z"
    }
    """.data(using: .utf8)!

    let notification = try? JSONDecoder().decode(AppNotification.self, from: json)
    XCTAssertNotNil(notification)
    XCTAssertEqual(notification?.priority, .unknown)
  }

  // MARK: - NotificationServiceError Tests

  func testNotificationServiceErrorDescriptions() {
    XCTAssertEqual(
      NotificationServiceError.notAuthenticated.errorDescription,
      "Session expired. Please log in again."
    )
    XCTAssertEqual(
      NotificationServiceError.networkTimeout.errorDescription,
      "Network timeout. Pull to refresh to try again."
    )
    XCTAssertEqual(
      NotificationServiceError.serverError(500).errorDescription,
      "Server error (500). Please try again later."
    )
    XCTAssertEqual(
      NotificationServiceError.serverError(503).errorDescription,
      "Server error (503). Please try again later."
    )
    XCTAssertEqual(
      NotificationServiceError.invalidResponse.errorDescription,
      "Invalid response from server."
    )
  }

  // MARK: - Helpers

  private func makeNotification(
    id: String,
    title: String = "Test",
    message: String = "Message",
    type: NotificationType = .followUpReminder,
    priority: NotificationPriority = .normal,
    readAt: String? = nil
  ) -> AppNotification {
    AppNotification(
      id: id,
      userId: "user",
      type: type,
      title: title,
      message: message,
      priority: priority,
      readAt: readAt,
      scheduledFor: "2026-02-15T10:00:00Z",
      sentAt: nil,
      emailSent: nil,
      emailSentAt: nil,
      actionUrl: nil,
      relatedEntityType: nil,
      relatedEntityId: nil,
      relatedSchoolId: nil,
      relatedCoachId: nil,
      relatedOfferId: nil,
      relatedEventId: nil,
      createdAt: nil,
      updatedAt: nil
    )
  }
}
