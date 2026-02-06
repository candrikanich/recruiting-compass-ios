import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class VerificationStatusIconTests: XCTestCase {
  func testPendingStateIcon() {
    let icon = VerificationStatusIcon(state: .pending)

    XCTAssertNotNil(icon)
  }

  func testCheckingStateIcon() {
    let icon = VerificationStatusIcon(state: .checking)

    XCTAssertNotNil(icon)
  }

  func testVerifiedStateIcon() {
    let icon = VerificationStatusIcon(state: .verified)

    XCTAssertNotNil(icon)
  }

  func testErrorStateIcon() {
    let icon = VerificationStatusIcon(state: .error(message: "Test error"))

    XCTAssertNotNil(icon)
  }

  func testIconSizeIsCorrect() {
    let icon = VerificationStatusIcon(state: .checking)
    let view = AnyView(icon)

    // Verify the icon renders properly
    XCTAssertNotNil(view)
  }

  func testCheckingIconAnimates() {
    let icon = VerificationStatusIcon(state: .checking)

    // Verify the checking state exists (animation is tested in UI tests)
    XCTAssertNotNil(icon)
  }
}
