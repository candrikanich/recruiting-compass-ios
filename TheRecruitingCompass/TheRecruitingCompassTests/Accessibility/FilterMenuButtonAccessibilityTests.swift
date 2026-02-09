import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FilterMenuButtonAccessibilityTests: XCTestCase {

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

  func testInactiveButton_HasCorrectLabel() {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Should announce just the label when inactive
    XCTAssertEqual(view.accessibilityLabel, "Type")
  }

  func testActiveButton_HasCorrectLabel() {
    let button = FilterMenuButton(
      label: "Email",
      isActive: true,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Should announce label + active state
    XCTAssertEqual(view.accessibilityLabel, "Email, active")
  }

  func testCapsuleStyle_HasCorrectLabel() {
    let button = FilterMenuButton(
      label: "Direction",
      isActive: true,
      style: .capsule
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Should announce label + active state regardless of style
    XCTAssertEqual(view.accessibilityLabel, "Direction, active")
  }

  // MARK: - Accessibility Traits

  func testButton_HasButtonTrait() {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Should have button trait
    XCTAssertTrue(view.accessibilityTraits.contains(.button))
  }

  // MARK: - Touch Target

  func testButton_MeetsMinimumTouchTarget() {
    let button = FilterMenuButton(
      label: "Type",
      isActive: false,
      style: .rounded
    )

    let hostingController = UIHostingController(rootView: button)
    let view = hostingController.view!

    // Force layout
    hostingController.view.layoutIfNeeded()

    // Should have minimum 44pt height
    XCTAssertGreaterThanOrEqual(view.frame.height, 44.0)
  }

  func testButton_MeetsMinimumTouchTarget_AtLargeDynamicType() {
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

    // Should maintain minimum 44pt height even at large text sizes
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
