import XCTest
import SwiftUI
@testable import TheRecruitingCompass

final class PasswordStrengthIndicatorTests: XCTestCase {
  func testPasswordStrengthIndicatorWithEmptyPassword() {
    let indicator = PasswordStrengthIndicator(password: "")
    XCTAssertNotNil(indicator)
  }

  func testPasswordStrengthIndicatorWithWeakPassword() {
    let indicator = PasswordStrengthIndicator(password: "weak")
    XCTAssertNotNil(indicator)
  }

  func testPasswordStrengthIndicatorWithFairPassword() {
    let indicator = PasswordStrengthIndicator(password: "Password12")
    XCTAssertNotNil(indicator)
  }

  func testPasswordStrengthIndicatorWithStrongPassword() {
    let indicator = PasswordStrengthIndicator(password: "StrongPass123")
    XCTAssertNotNil(indicator)
  }
}
