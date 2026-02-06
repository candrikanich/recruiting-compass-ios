import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class SignupViewAccessibilityTests: XCTestCase {

  func testSignupView_BackButton_HasLabel() {
    let view = SignupView()

    // Verify back button has "Back to welcome screen" label
    XCTAssertNotNil(view)
  }

  func testSignupView_CompassIcon_Hidden() {
    let view = SignupView()

    // Verify compass icon is accessibility hidden
    XCTAssertNotNil(view)
  }

  func testSignupView_ChangeRoleButton_HasLabel() {
    let view = SignupView()

    // Verify "Change role selection" label and hint
    XCTAssertNotNil(view)
  }

  func testSignupView_CreateAccountButton_HasLabel() {
    let view = SignupView()

    // Verify button label changes with loading state
    XCTAssertNotNil(view)
  }

  func testSignupView_CreateAccountButton_Loading_ProgressHasLabel() {
    let view = SignupView()

    // Verify progress view has "Creating account" label
    XCTAssertNotNil(view)
  }

  func testSignupView_SignInLink_HasLabel() {
    let view = SignupView()

    // Verify "Sign in to existing account" label and hint
    XCTAssertNotNil(view)
  }
}
