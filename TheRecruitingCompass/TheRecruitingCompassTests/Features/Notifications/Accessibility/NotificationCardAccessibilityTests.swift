import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class NotificationCardAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeCard(_ notification: AppNotification) -> NotificationCard {
    NotificationCard(notification: notification, onTap: {}, onMarkRead: {}, onDelete: {})
  }

  // MARK: - Accessibility Label

  func testCard_HasComprehensiveLabel_UnreadFollowUp() {
    let notification = createNotification(
      type: .followUpReminder,
      title: "Follow up with Coach Smith",
      message: "It's been 7 days since your last email",
      priority: .normal,
      readAt: nil
    )

    let label = makeCard(notification).accessibilityLabel

    XCTAssertTrue(label.contains("Follow up with Coach Smith"), "Label should include notification title")
    XCTAssertTrue(label.lowercased().contains("unread"), "Label should indicate unread state")
    XCTAssertTrue(label.contains("Follow-ups"), "Label should include notification type context")
  }

  func testCard_HasComprehensiveLabel_ReadDeadline() {
    let notification = createNotification(
      type: .deadlineAlert,
      title: "Deadline approaching: Stanford application",
      message: "Due in 3 days",
      priority: .high,
      readAt: ISO8601DateFormatter().string(from: Date())
    )

    let label = makeCard(notification).accessibilityLabel

    XCTAssertTrue(label.contains("Deadline approaching"), "Label should include notification title")
    XCTAssertFalse(label.lowercased().contains("unread"), "Read notification should not say unread")
    XCTAssertTrue(label.contains("Read"), "Read notification should announce read state")
  }

  func testCard_LabelIncludesPriority_High() {
    let notification = createNotification(priority: .high)

    let label = makeCard(notification).accessibilityLabel

    XCTAssertTrue(label.contains("High priority"), "High priority notifications should announce priority level")
  }

  func testCard_LabelOmitsPriority_WhenNotHigh() {
    let normal = makeCard(createNotification(priority: .normal)).accessibilityLabel
    let low = makeCard(createNotification(priority: .low)).accessibilityLabel

    XCTAssertFalse(normal.contains("priority"), "Normal priority should not announce a priority level")
    XCTAssertFalse(low.contains("priority"), "Low priority should not announce a priority level")
  }

  // MARK: - Read/Unread State Distinction (WCAG 1.4.1)

  func testCard_ReadState_IsConveyedBeyondColor() {
    let unreadLabel = makeCard(createNotification(readAt: nil)).accessibilityLabel
    let readLabel = makeCard(
      createNotification(readAt: ISO8601DateFormatter().string(from: Date()))
    ).accessibilityLabel

    XCTAssertTrue(unreadLabel.contains("Unread"), "Unread state must be conveyed as text, not color alone")
    XCTAssertTrue(readLabel.contains("Read"), "Read state must be conveyed as text, not color alone")
    XCTAssertNotEqual(unreadLabel, readLabel, "Read and unread cards should announce different labels")
  }

  // MARK: - Decorative Elements
  //
  // The card hides the type emoji via `.accessibilityHidden(true)` and uses an
  // `.accessibilityElement(children: .combine)` container with a button trait
  // and a "Tap to view details" hint applied in the SwiftUI body. Those
  // modifiers are not introspectable from a unit test (SwiftUI does not expose
  // its accessibility tree to UIHostingController in unit tests), so the
  // assertions below exercise the underlying label data instead. The hidden
  // state, button trait, and navigation hint are verified by the E2E/VoiceOver
  // audit.

  func testCard_TypeContextConveyedViaLabelNotEmojiAlone() {
    let notification = createNotification(type: .deadlineAlert)
    let label = makeCard(notification).accessibilityLabel
    XCTAssertTrue(label.contains("Deadlines"), "Type must be conveyed as text, not the decorative emoji alone")
  }

  // MARK: - Helper Methods

  private func createNotification(
    id: String = UUID().uuidString,
    type: NotificationType = .followUpReminder,
    title: String = "Test Notification",
    message: String = "Test message content",
    priority: NotificationPriority = .normal,
    readAt: String? = nil
  ) -> AppNotification {
    AppNotification(
      id: id,
      userId: "user1",
      type: type,
      title: title,
      message: message,
      priority: priority,
      readAt: readAt,
      scheduledFor: ISO8601DateFormatter().string(from: Date()),
      sentAt: ISO8601DateFormatter().string(from: Date()),
      emailSent: nil,
      emailSentAt: nil,
      actionUrl: nil,
      relatedEntityType: nil,
      relatedEntityId: nil,
      relatedSchoolId: nil,
      relatedCoachId: nil,
      relatedOfferId: nil,
      relatedEventId: nil,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      updatedAt: ISO8601DateFormatter().string(from: Date())
    )
  }
}
