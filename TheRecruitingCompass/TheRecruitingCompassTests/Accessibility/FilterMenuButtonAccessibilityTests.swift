import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FilterMenuButtonAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  private func makeButton(
    label: String,
    isActive: Bool,
    style: FilterMenuButton.Style = .capsule
  ) -> FilterMenuButton {
    FilterMenuButton(label: label, isActive: isActive, style: style)
  }

  // MARK: - Accessibility Label

  func testInactiveButton_HasCorrectLabel() {
    let button = makeButton(label: "Type", isActive: false, style: .rounded)
    XCTAssertEqual(button.accessibilityLabel, "Type", "Inactive button should announce just the label")
  }

  func testActiveButton_HasCorrectLabel() {
    let button = makeButton(label: "Email", isActive: true, style: .rounded)
    XCTAssertEqual(button.accessibilityLabel, "Email, active", "Active button should announce label + active state")
  }

  func testCapsuleStyle_HasCorrectLabel() {
    let button = makeButton(label: "Direction", isActive: true, style: .capsule)
    XCTAssertEqual(
      button.accessibilityLabel,
      "Direction, active",
      "Active state should be announced regardless of style"
    )
  }

  // MARK: - Decorative Chevron / Traits / Touch Target
  //
  // The button hides the decorative chevron via `.accessibilityHidden(true)`,
  // adds `.isButton` via `.accessibilityAddTraits`, and enforces a 44pt minimum
  // height via `.frame(minHeight: 44)` in the SwiftUI body. None of those
  // modifiers are introspectable from a unit test (SwiftUI does not expose its
  // accessibility tree or auto-size views in UIHostingController), so we assert
  // on the label data the button relies on instead. Hidden state, button trait,
  // and touch-target sizing are verified by the E2E/VoiceOver audit.

  func testActiveStateConveyedViaLabelNotStyleAlone() {
    let button = makeButton(label: "Type", isActive: true, style: .rounded)
    XCTAssertTrue(
      button.accessibilityLabel.contains("active"),
      "Active state must be conveyed as text, not color/weight alone"
    )
  }
}
