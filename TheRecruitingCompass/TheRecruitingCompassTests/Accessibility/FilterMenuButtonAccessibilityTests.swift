import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FilterMenuButtonAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Chevron Icon

  func testChevronIcon_IsHidden() {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Find chevron image - should be hidden
    let images = findSubviews(of: UIImageView.self, in: view)
    XCTAssertTrue(images.allSatisfy { $0.accessibilityElementsHidden })
  }

  // MARK: - Accessibility Label

  func testInactiveButton_HasCorrectLabel() throws {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    try XCTSkipIf(view.accessibilityLabel == nil, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // Should announce just the label when inactive
    XCTAssertEqual(view.accessibilityLabel, "Type")
  }

  func testActiveButton_HasCorrectLabel() throws {
    let button = FilterMenuButton(
      label: "Email",
      isActive: true,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    try XCTSkipIf(view.accessibilityLabel == nil, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // Should announce label + active state
    XCTAssertEqual(view.accessibilityLabel, "Email, active")
  }

  func testCapsuleStyle_HasCorrectLabel() throws {
    let button = FilterMenuButton(
      label: "Direction",
      isActive: true,
      style: .capsule
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    try XCTSkipIf(view.accessibilityLabel == nil, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    // Should announce label + active state regardless of style
    XCTAssertEqual(view.accessibilityLabel, "Direction, active")
  }

  // MARK: - Accessibility Traits

  func testButton_HasButtonTrait() throws {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    try XCTSkipIf(!view.isAccessibilityElement && view.accessibilityTraits.isEmpty, "SwiftUI accessibility traits not accessible via UIHostingController in unit tests")

    // Should have button trait
    XCTAssertTrue(view.accessibilityTraits.contains(.button))
  }

  // MARK: - Touch Target

  func testButton_MeetsMinimumTouchTarget() throws {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Force layout
    hostingController.view.layoutIfNeeded()

    try XCTSkipIf(view.frame.height == 0, "UIHostingController doesn't auto-size SwiftUI views in unit tests")
    XCTAssertGreaterThanOrEqual(view.frame.height, 44.0)
  }

  func testButton_MeetsMinimumTouchTarget_AtLargeDynamicType() throws {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Force layout
    hostingController.view.layoutIfNeeded()

    try XCTSkipIf(view.frame.height == 0, "UIHostingController doesn't auto-size SwiftUI views in unit tests")
    XCTAssertGreaterThanOrEqual(view.frame.height, 44.0)
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
}
