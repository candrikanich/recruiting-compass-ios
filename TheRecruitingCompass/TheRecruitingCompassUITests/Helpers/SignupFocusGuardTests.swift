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

  // Frames from the 2026-10-16 nightly repro: the form card's scroll view with the keyboard up.
  private let scrollFrame = CGRect(x: 24, y: 133.7, width: 354, height: 359.3)
  private let nightlyKeyboard = CGRect(x: 0, y: 590, width: 402, height: 226)

  func testFieldJustBelowVisibleAreaLandsInsideItWithoutOvershooting() {
    let field = CGRect(x: 100, y: 533.7, width: 234, height: 21)
    let visible = SignupScreenObject.visibleFormArea(scrollFrame: scrollFrame, keyboardFrame: nightlyKeyboard)
    let offset = SignupScreenObject.dragOffset(toReveal: field, in: visible)
    XCTAssertTrue(visible.contains(field.offsetBy(dx: 0, dy: offset)))
  }

  func testFieldScrolledAboveVisibleAreaDragsBackDown() {
    let field = CGRect(x: 100, y: -43, width: 234, height: 21)
    let visible = SignupScreenObject.visibleFormArea(scrollFrame: scrollFrame, keyboardFrame: nightlyKeyboard)
    XCTAssertGreaterThan(SignupScreenObject.dragOffset(toReveal: field, in: visible), 0)
  }

  func testDragOffsetIsCappedSoTheGestureStaysInsideTheScrollView() {
    let field = CGRect(x: 100, y: 2_000, width: 234, height: 21)
    let visible = SignupScreenObject.visibleFormArea(scrollFrame: scrollFrame, keyboardFrame: nightlyKeyboard)
    XCTAssertLessThan(abs(SignupScreenObject.dragOffset(toReveal: field, in: visible)), visible.height / 2)
  }

  func testVisibleFormAreaStopsAtTheKeyboard() {
    let tall = CGRect(x: 0, y: 100, width: 402, height: 700)
    XCTAssertEqual(
      SignupScreenObject.visibleFormArea(scrollFrame: tall, keyboardFrame: nightlyKeyboard).maxY, 590)
  }
}
