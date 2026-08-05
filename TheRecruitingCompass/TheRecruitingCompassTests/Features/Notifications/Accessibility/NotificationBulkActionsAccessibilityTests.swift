import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class NotificationBulkActionsAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeBulkActions(
    hasUnread: Bool = true,
    hasRead: Bool = true
  ) -> NotificationBulkActions {
    NotificationBulkActions(
      hasUnread: hasUnread,
      hasRead: hasRead,
      onMarkAllRead: {},
      onClearRead: {}
    )
  }

  // MARK: - Descriptive Labels

  func testMarkAllReadButton_HasDescriptiveLabel() {
    // ScreenObject expects: buttons["Mark all as read"]
    let actions = makeBulkActions()
    XCTAssertEqual(actions.markAllReadAccessibilityLabel, "Mark all as read",
                   "Mark all read button should have descriptive label")
  }

  func testClearReadButton_HasDescriptiveLabel() {
    // ScreenObject expects: buttons["Clear read notifications"]
    let actions = makeBulkActions()
    XCTAssertEqual(actions.clearReadAccessibilityLabel, "Clear read notifications",
                   "Clear read button should have descriptive label")
  }

  // MARK: - Enabled / Disabled State
  //
  // Both buttons apply `.disabled(...)` driven by `hasUnread` / `hasRead` in the
  // SwiftUI body, and SwiftUI propagates `.notEnabled` to VoiceOver from that
  // modifier. The disabled accessibility trait is not introspectable from a unit
  // test (SwiftUI does not expose its accessibility tree to UIHostingController),
  // so the assertions below verify the flags that drive the disabled state. The
  // `.notEnabled` trait itself is verified by the E2E/VoiceOver audit.

  func testMarkAllRead_DisabledFlag_WhenNoUnread() {
    let actions = makeBulkActions(hasUnread: false, hasRead: true)
    XCTAssertFalse(actions.hasUnread, "Mark all read should be disabled (hasUnread == false) when no unread exist")
  }

  func testMarkAllRead_EnabledFlag_WhenUnreadExist() {
    let actions = makeBulkActions(hasUnread: true, hasRead: false)
    XCTAssertTrue(actions.hasUnread, "Mark all read should be enabled when unread notifications exist")
  }

  func testClearRead_DisabledFlag_WhenNoRead() {
    let actions = makeBulkActions(hasUnread: true, hasRead: false)
    XCTAssertFalse(actions.hasRead, "Clear read should be disabled (hasRead == false) when no read exist")
  }

  func testClearRead_EnabledFlag_WhenReadExist() {
    let actions = makeBulkActions(hasUnread: false, hasRead: true)
    XCTAssertTrue(actions.hasRead, "Clear read should be enabled when read notifications exist")
  }
}
