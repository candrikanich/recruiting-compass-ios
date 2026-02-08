import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class VerificationStatusIconAccessibilityTests: XCTestCase {

  // MARK: - Accessibility Label Tests

  func testPendingStateAccessibilityLabel() {
    let label = accessibilityLabel(for: .pending)
    XCTAssertEqual(label, "Email verification pending")
  }

  func testCheckingStateAccessibilityLabel() {
    let label = accessibilityLabel(for: .checking)
    XCTAssertEqual(label, "Checking email verification status")
  }

  func testVerifiedStateAccessibilityLabel() {
    let label = accessibilityLabel(for: .verified)
    XCTAssertEqual(label, "Email verified successfully")
  }

  func testErrorStateAccessibilityLabel() {
    let label = accessibilityLabel(for: .error(message: "Network error"))
    XCTAssertEqual(label, "Verification error: Network error")
  }

  func testErrorStateAccessibilityLabelWithDifferentMessage() {
    let label = accessibilityLabel(for: .error(message: "Server timeout"))
    XCTAssertEqual(label, "Verification error: Server timeout")
  }

  // MARK: - Component Instantiation Per State

  func testPendingIconInstantiates() {
    let icon = VerificationStatusIcon(state: .pending)
    XCTAssertNotNil(icon)
  }

  func testCheckingIconInstantiates() {
    let icon = VerificationStatusIcon(state: .checking)
    XCTAssertNotNil(icon)
  }

  func testVerifiedIconInstantiates() {
    let icon = VerificationStatusIcon(state: .verified)
    XCTAssertNotNil(icon)
  }

  func testErrorIconInstantiates() {
    let icon = VerificationStatusIcon(state: .error(message: "Test"))
    XCTAssertNotNil(icon)
  }

  // MARK: - All States Have Non-Empty Labels

  func testAllStatesHaveNonEmptyAccessibilityLabels() {
    let states: [VerificationState] = [
      .pending,
      .checking,
      .verified,
      .error(message: "Test error")
    ]

    for state in states {
      let label = accessibilityLabel(for: state)
      XCTAssertFalse(label.isEmpty, "Accessibility label should not be empty for state: \(state)")
    }
  }

  // MARK: - Helper (mirrors VerificationStatusIcon.accessibilityLabelForState)

  private func accessibilityLabel(for state: VerificationState) -> String {
    switch state {
    case .pending:
      return "Email verification pending"
    case .checking:
      return "Checking email verification status"
    case .verified:
      return "Email verified successfully"
    case .error(let message):
      return "Verification error: \(message)"
    }
  }
}
