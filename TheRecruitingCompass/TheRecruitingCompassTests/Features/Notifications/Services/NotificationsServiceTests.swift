import XCTest
@testable import TheRecruitingCompass

@MainActor
final class NotificationsServiceTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Service Initialization

  func testServiceInitializes() {
    let service = NotificationsServiceImpl(supabaseManager: SupabaseManager.shared)
    XCTAssertNotNil(service)
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
      NotificationServiceError.invalidResponse.errorDescription,
      "Invalid response from server."
    )
  }

  func testNotificationServiceError_ServerErrorWithDifferentCodes() {
    XCTAssertEqual(
      NotificationServiceError.serverError(400).errorDescription,
      "Server error (400). Please try again later."
    )
    XCTAssertEqual(
      NotificationServiceError.serverError(503).errorDescription,
      "Server error (503). Please try again later."
    )
    XCTAssertEqual(
      NotificationServiceError.serverError(429).errorDescription,
      "Server error (429). Please try again later."
    )
  }

  // MARK: - MockNotificationsService Tests

  func testMockService_FetchNotifications_ReturnsNotifications() async throws {
    // Given
    let mock = MockNotificationsService()
    mock.mockNotifications = [
      makeNotification(id: "1"),
      makeNotification(id: "2"),
      makeNotification(id: "3")
    ]

    // When
    let results = try await mock.fetchNotifications(userId: "user-1")

    // Then
    XCTAssertEqual(results.count, 3)
  }

  func testMockService_FetchNotifications_ThrowsWhenNotSucceeding() async {
    // Given
    let mock = MockNotificationsService()
    mock.shouldSucceed = false

    // When/Then
    do {
      _ = try await mock.fetchNotifications(userId: "user-1")
      XCTFail("Expected error to be thrown")
    } catch {
      XCTAssertTrue(error is NotificationServiceError)
    }
  }

  func testMockService_MarkAsRead_UpdatesNotification() async throws {
    // Given
    let mock = MockNotificationsService()
    mock.mockNotifications = [makeNotification(id: "1", readAt: nil)]
    XCTAssertFalse(mock.mockNotifications[0].isRead)

    // When
    let updated = try await mock.markAsRead(id: "1")

    // Then
    XCTAssertTrue(updated.isRead)
    XCTAssertNotNil(updated.readAt)
    XCTAssertEqual(mock.markAsReadCallCount, 1)
    XCTAssertEqual(mock.lastMarkedReadId, "1")
  }

  func testMockService_MarkAsRead_ThrowsForInvalidId() async {
    // Given
    let mock = MockNotificationsService()
    mock.mockNotifications = [makeNotification(id: "1")]

    // When/Then
    do {
      _ = try await mock.markAsRead(id: "nonexistent")
      XCTFail("Expected error for nonexistent ID")
    } catch {
      XCTAssertTrue(error is NotificationServiceError)
    }
  }

  func testMockService_MarkAllAsRead_IncreasesCallCount() async throws {
    // Given
    let mock = MockNotificationsService()

    // When
    try await mock.markAllAsRead(userId: "user-1")

    // Then
    XCTAssertEqual(mock.markAllAsReadCallCount, 1)
  }

  func testMockService_DeleteNotification_RemovesFromArray() async throws {
    // Given
    let mock = MockNotificationsService()
    mock.mockNotifications = [
      makeNotification(id: "1"),
      makeNotification(id: "2"),
      makeNotification(id: "3")
    ]

    // When
    try await mock.deleteNotification(id: "2")

    // Then
    XCTAssertEqual(mock.mockNotifications.count, 2)
    XCTAssertFalse(mock.mockNotifications.contains { $0.id == "2" })
    XCTAssertEqual(mock.deleteCallCount, 1)
    XCTAssertEqual(mock.lastDeletedId, "2")
  }

  func testMockService_DeleteAllRead_RemovesOnlyRead() async throws {
    // Given
    let mock = MockNotificationsService()
    mock.mockNotifications = [
      makeNotification(id: "1", readAt: nil),
      makeNotification(id: "2", readAt: "2026-02-15T10:00:00Z"),
      makeNotification(id: "3", readAt: nil),
      makeNotification(id: "4", readAt: "2026-02-15T11:00:00Z")
    ]

    // When
    try await mock.deleteAllRead(userId: "user-1")

    // Then
    XCTAssertEqual(mock.mockNotifications.count, 2)
    XCTAssertTrue(mock.mockNotifications.allSatisfy { !$0.isRead })
    XCTAssertEqual(mock.deleteAllReadCallCount, 1)
  }

  func testMockService_Reset_ClearsState() async throws {
    // Given
    let mock = MockNotificationsService()
    mock.shouldSucceed = false
    mock.mockNotifications = [makeNotification(id: "1")]
    mock.markAsReadCallCount = 5
    mock.deleteCallCount = 3

    // When
    mock.reset()

    // Then
    XCTAssertTrue(mock.shouldSucceed)
    XCTAssertTrue(mock.mockNotifications.isEmpty)
    XCTAssertEqual(mock.markAsReadCallCount, 0)
    XCTAssertEqual(mock.deleteCallCount, 0)
    XCTAssertNil(mock.lastMarkedReadId)
    XCTAssertNil(mock.lastDeletedId)
  }

  // MARK: - Helpers

  private func makeNotification(
    id: String,
    readAt: String? = nil
  ) -> AppNotification {
    AppNotification(
      id: id,
      userId: "user-1",
      type: .followUpReminder,
      title: "Test Notification \(id)",
      message: "Test message for \(id)",
      priority: .normal,
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
      createdAt: "2026-02-15T09:00:00Z",
      updatedAt: nil
    )
  }
}
