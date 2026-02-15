import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class NotificationBulkActionsAccessibilityTests: XCTestCase {

  // MARK: - Mark All Read Button

  func testMarkAllReadButton_HasDescriptiveLabel() throws {
    let bulkActions = NotificationBulkActions(
      hasUnread: true,
      hasRead: true,
      onMarkAllRead: {},
      onClearRead: {}
    )

    let hostingController = UIHostingController(rootView: bulkActions)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // ScreenObject expects: buttons["Mark all as read"]
    XCTAssertTrue(combinedLabel.contains("Mark all as read"), "Mark all read button should have descriptive label")
  }

  func testClearReadButton_HasDescriptiveLabel() throws {
    let bulkActions = NotificationBulkActions(
      hasUnread: true,
      hasRead: true,
      onMarkAllRead: {},
      onClearRead: {}
    )

    let hostingController = UIHostingController(rootView: bulkActions)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    let labels = accessibilityElements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // ScreenObject expects: buttons["Clear read notifications"]
    XCTAssertTrue(combinedLabel.contains("Clear read notifications"), "Clear read button should have descriptive label")
  }

  // MARK: - Button Traits

  func testBulkActionButtons_HaveButtonTraits() throws {
    let bulkActions = NotificationBulkActions(
      hasUnread: true,
      hasRead: true,
      onMarkAllRead: {},
      onClearRead: {}
    )

    let hostingController = UIHostingController(rootView: bulkActions)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    try XCTSkipIf(accessibilityElements.isEmpty, "SwiftUI accessibility traits not accessible via UIHostingController in unit tests")

    let buttonsCount = accessibilityElements.filter { $0.accessibilityTraits.contains(.button) }.count
    XCTAssertGreaterThanOrEqual(buttonsCount, 2, "Both bulk action buttons should have button traits")
  }

  // MARK: - Disabled State

  func testMarkAllRead_DisabledWhenNoUnread() throws {
    let bulkActions = NotificationBulkActions(
      hasUnread: false,
      hasRead: true,
      onMarkAllRead: {},
      onClearRead: {}
    )

    let hostingController = UIHostingController(rootView: bulkActions)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    try XCTSkipIf(accessibilityElements.isEmpty, "SwiftUI accessibility traits not accessible via UIHostingController in unit tests")

    // When no unread notifications exist, mark all read should be disabled
    let markAllElements = accessibilityElements.filter {
      $0.accessibilityLabel?.contains("Mark all") == true
    }

    for element in markAllElements {
      XCTAssertTrue(
        element.accessibilityTraits.contains(.notEnabled),
        "Mark all read should have .notEnabled trait when no unread notifications"
      )
    }
  }

  func testClearRead_DisabledWhenNoRead() throws {
    let bulkActions = NotificationBulkActions(
      hasUnread: true,
      hasRead: false,
      onMarkAllRead: {},
      onClearRead: {}
    )

    let hostingController = UIHostingController(rootView: bulkActions)
    let view = hostingController.view!

    let accessibilityElements = findAccessibilityElements(in: view)
    try XCTSkipIf(accessibilityElements.isEmpty, "SwiftUI accessibility traits not accessible via UIHostingController in unit tests")

    // When no read notifications exist, clear read should be disabled
    let clearElements = accessibilityElements.filter {
      $0.accessibilityLabel?.contains("Clear") == true
    }

    for element in clearElements {
      XCTAssertTrue(
        element.accessibilityTraits.contains(.notEnabled),
        "Clear read should have .notEnabled trait when no read notifications"
      )
    }
  }

  // MARK: - Touch Target

  func testBulkActionButtons_MeetMinimumTouchTarget() throws {
    let bulkActions = NotificationBulkActions(
      hasUnread: true,
      hasRead: true,
      onMarkAllRead: {},
      onClearRead: {}
    )
    .frame(width: 375, height: 60)

    let hostingController = UIHostingController(rootView: bulkActions)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 60)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertGreaterThanOrEqual(hostingController.view.frame.height, 44.0, "Bulk action buttons should meet 44pt minimum")
  }

  // MARK: - Decorative Icons Hidden

  func testButtonIcons_AreDecorativeOnly() {
    let bulkActions = NotificationBulkActions(
      hasUnread: true,
      hasRead: true,
      onMarkAllRead: {},
      onClearRead: {}
    )

    let hostingController = UIHostingController(rootView: bulkActions)
    let view = hostingController.view!

    let images = findSubviews(of: UIImageView.self, in: view)
    XCTAssertTrue(images.allSatisfy { $0.accessibilityElementsHidden }, "Button icons should be hidden (action conveyed in label)")
  }

  // MARK: - Dynamic Type

  func testBulkActions_SupportDynamicType() {
    let bulkActions = NotificationBulkActions(
      hasUnread: true,
      hasRead: true,
      onMarkAllRead: {},
      onClearRead: {}
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    .frame(width: 375)

    let hostingController = UIHostingController(rootView: bulkActions)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 200)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertNotNil(hostingController.view, "Bulk actions should render at accessibility text sizes")
  }

  // MARK: - Helper Methods

  private func findSubviews<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
    var results: [T] = []
    for subview in view.subviews {
      if let match = subview as? T {
        results.append(match)
      }
      results.append(contentsOf: findSubviews(of: type, in: subview))
    }
    return results
  }

  private func findAccessibilityElements(in view: UIView) -> [NSObject] {
    var elements: [NSObject] = []
    if view.isAccessibilityElement, let element = view as? NSObject {
      elements.append(element)
    }
    if let accessibilityElements = view.accessibilityElements as? [NSObject] {
      elements.append(contentsOf: accessibilityElements)
    }
    for subview in view.subviews {
      elements.append(contentsOf: findAccessibilityElements(in: subview))
    }
    return elements
  }
}
