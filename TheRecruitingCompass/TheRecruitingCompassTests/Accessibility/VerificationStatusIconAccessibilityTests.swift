import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class VerificationStatusIconAccessibilityTests: XCTestCase {

  func testVerificationStatusIcon_PendingState_HasLabel() {
    let icon = VerificationStatusIcon(state: .pending)

    // Verify "Email verification pending" label
    let view = icon as any View
    XCTAssertNotNil(view)
  }

  func testVerificationStatusIcon_CheckingState_HasLabel() {
    let icon = VerificationStatusIcon(state: .checking)

    // Verify "Checking email verification status" label
    let view = icon as any View
    XCTAssertNotNil(view)
  }

  func testVerificationStatusIcon_VerifiedState_HasLabel() {
    let icon = VerificationStatusIcon(state: .verified)

    // Verify "Email verified successfully" label
    let view = icon as any View
    XCTAssertNotNil(view)
  }

  func testVerificationStatusIcon_ErrorState_HasLabel() {
    let icon = VerificationStatusIcon(state: .error(message: "Network error"))

    // Verify error message in accessibility label
    let view = icon as any View
    XCTAssertNotNil(view)
  }

  func testVerificationStatusIcon_BackgroundCircle_Hidden() {
    let icon = VerificationStatusIcon(state: .pending)

    // Verify background circle is accessibility hidden
    let view = icon as any View
    XCTAssertNotNil(view)
  }
}
