import XCTest

/// Pure geometry checks for `SignupScreenObject.isTapSafe`; no app launch, so no backend is touched.
final class SignupFocusGuardTests: XCTestCase {
  private let keyboard = CGRect(x: 0, y: 500, width: 400, height: 300)

  func testFieldUnderKeyboardIsNotTapSafe() {
    let field = CGRect(x: 20, y: 540, width: 360, height: 44)
    XCTAssertFalse(SignupScreenObject.isTapSafe(fieldFrame: field, hittable: true, keyboardFrame: keyboard))
  }

  func testFieldStraddlingKeyboardEdgeIsNotTapSafe() {
    let field = CGRect(x: 20, y: 470, width: 360, height: 44)
    XCTAssertFalse(SignupScreenObject.isTapSafe(fieldFrame: field, hittable: true, keyboardFrame: keyboard))
  }

  func testFieldAboveKeyboardIsTapSafe() {
    let field = CGRect(x: 20, y: 400, width: 360, height: 44)
    XCTAssertTrue(SignupScreenObject.isTapSafe(fieldFrame: field, hittable: true, keyboardFrame: keyboard))
  }

  func testNonHittableFieldIsNotTapSafe() {
    let field = CGRect(x: 20, y: 100, width: 360, height: 44)
    XCTAssertFalse(SignupScreenObject.isTapSafe(fieldFrame: field, hittable: false, keyboardFrame: keyboard))
  }

  func testWithoutKeyboardHittableFieldIsTapSafe() {
    let field = CGRect(x: 20, y: 540, width: 360, height: 44)
    XCTAssertTrue(SignupScreenObject.isTapSafe(fieldFrame: field, hittable: true, keyboardFrame: nil))
  }
}
