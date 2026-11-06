import XCTest

final class SignupScreenObject {
  private let app: XCUIApplication

  init(app: XCUIApplication) {
    self.app = app
  }

  // MARK: - Landing Screen Elements

  var landingSignInButton: XCUIElement {
    app.buttons["Sign in to your account"]
  }

  var landingCreateAccountButton: XCUIElement {
    app.buttons["Start now — create a new account"]
  }

  // MARK: - Role Selection Elements

  var selectYourRoleText: XCUIElement {
    app.staticTexts["Select Your Role"]
  }

  var parentRoleCard: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Parent role'")).firstMatch
  }

  var studentRoleCard: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Student role'")).firstMatch
  }

  var playerRoleCard: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label CONTAINS 'Player role'")).firstMatch
  }

  // MARK: - Signup Form Elements

  var changeRoleButton: XCUIElement {
    app.buttons["Change role selection"]
  }

  // Each LoginFormField is an "Other" container (label + icon + input) whose identifier is
  // the field name; the input inside carries the same accessibility label. Target the
  // input itself: tapping the container's center can land on the keyboard once the form
  // has scrolled (nightly run 37124806803, Email field), leaving nothing focused.
  var firstNameField: XCUIElement {
    app.textFields["First Name"].firstMatch
  }

  var lastNameField: XCUIElement {
    app.textFields["Last Name"].firstMatch
  }

  var emailField: XCUIElement {
    app.textFields["Email"].firstMatch
  }

  var passwordField: XCUIElement {
    app.secureTextFields["Password"].firstMatch
  }

  var confirmPasswordField: XCUIElement {
    app.secureTextFields["Confirm Password"].firstMatch
  }

  var familyCodeField: XCUIElement {
    app.otherElements["Family Code (Optional)"].firstMatch
  }

  var termsCheckbox: XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'I agree to the Terms of Service'")
    ).firstMatch
  }

  /// Tappable "Terms of Service" link that opens the Terms sheet
  var termsOfServiceLink: XCUIElement {
    app.buttons["Read Terms of Service"]
  }

  /// "Privacy Policy" link that opens the Privacy Policy sheet
  var privacyPolicyLink: XCUIElement {
    app.buttons["Read Privacy Policy"]
  }

  var createAccountButton: XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "label == 'Create account'")
    ).firstMatch
  }

  var signInLink: XCUIElement {
    app.buttons["Sign in to existing account"]
  }

  var backButton: XCUIElement {
    app.buttons["Back to welcome screen"]
  }

  // MARK: - Error Elements

  func errorBanner(containing text: String) -> XCUIElement {
    // Use descendants(matching: .any) to find combined accessibility elements
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS[cd] %@", text)
    ).firstMatch
  }

  var passwordStrengthWeak: XCUIElement {
    // Password strength is a combined accessibility element, not a static text
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS 'Password strength: Weak'")
    ).firstMatch
  }

  var passwordStrengthFair: XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS 'Password strength: Fair'")
    ).firstMatch
  }

  var passwordStrengthStrong: XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS 'Password strength: Strong'")
    ).firstMatch
  }

  // MARK: - Actions

  func navigateToSignup() {
    landingCreateAccountButton.waitAndTap()
  }

  func selectRole(_ role: TestUserRole) {
    let card: XCUIElement
    switch role {
    case .parent: card = parentRoleCard
    case .player: card = playerRoleCard
    }
    // Use waitForExistence + tap() instead of waitAndTap() so XCTest can
    // auto-scroll to the card if it's off-screen in the ScrollView.
    guard card.waitForExistence(timeout: 10) else { return }
    card.tap()
  }

  func fillSignupForm(with data: TestUserData, file: StaticString = #filePath, line: UInt = #line) {
    let nameParts = data.fullName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    let first = nameParts.first.map(String.init) ?? data.fullName
    let last = nameParts.count > 1 ? String(nameParts[1]) : ""

    guard firstNameField.waitForExistence(timeout: 10) else {
      XCTFail("Signup form did not appear", file: file, line: line)
      return
    }
    focusAndType(firstNameField, first, file: file, line: line)
    if !last.isEmpty { focusAndType(lastNameField, last, file: file, line: line) }
    focusAndType(emailField, data.email, file: file, line: line)
    focusAndType(passwordField, data.password, file: file, line: line)
    focusAndType(confirmPasswordField, data.password, file: file, line: line)

    if let familyCode = data.familyCode, familyCodeField.waitForExistence(timeout: 1) {
      focusAndType(familyCodeField, familyCode, file: file, line: line)
    }
  }

  /// With the keyboard up the scroll view shrinks, so a field near its bottom edge can sit under the
  /// keyboard. Tapping there lands on a key and types a stray character into the field that already has
  /// focus, so retries scroll first and only tap once the field is hittable and clear of the keyboard.
  /// Retries drag by the field's measured distance rather than swiping: even a slow swipe flings about a
  /// screen, which carried Password from just below the visible card to above it (nightly 2026-10-16).
  private func focusAndType(
    _ field: XCUIElement, _ text: String, file: StaticString, line: UInt
  ) {
    let hasFocus = NSPredicate(format: "hasKeyboardFocus == true")
    let scrollView = app.scrollViews.firstMatch
    for _ in 0..<4 {
      let keyboard = app.keyboards.firstMatch
      let keyboardFrame = keyboard.exists ? keyboard.frame : nil
      if Self.isTapSafe(fieldFrame: field.frame, hittable: field.isHittable, keyboardFrame: keyboardFrame) {
        field.tap()
        let focused = XCTNSPredicateExpectation(predicate: hasFocus, object: field)
        if XCTWaiter.wait(for: [focused], timeout: 2) == .completed {
          field.typeText(text)
          return
        }
      }
      let visible = Self.visibleFormArea(scrollFrame: scrollView.frame, keyboardFrame: keyboardFrame)
      drag(from: visible, by: Self.dragOffset(toReveal: field.frame, in: visible))
    }
    XCTFail("Could not focus \(field.identifier.isEmpty ? field.label : field.identifier)", file: file, line: line)
  }

  /// Holds before releasing so the scroll view stops where the finger does, with no momentum. Starts in
  /// the card's side padding: a drag that begins on the focused field moves its caret instead of scrolling.
  private func drag(from visible: CGRect, by offset: CGFloat) {
    let origin = app.coordinate(withNormalizedOffset: .zero)
    let start = origin.withOffset(CGVector(dx: visible.minX + 12, dy: visible.midY))
    start.press(
      forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: offset)),
      withVelocity: .slow, thenHoldForDuration: 0.3)
  }

  static func isTapSafe(fieldFrame: CGRect, hittable: Bool, keyboardFrame: CGRect?) -> Bool {
    guard hittable else { return false }
    guard let keyboardFrame else { return true }
    return !fieldFrame.intersects(keyboardFrame)
  }

  static func visibleFormArea(scrollFrame: CGRect, keyboardFrame: CGRect?) -> CGRect {
    guard let keyboardFrame, keyboardFrame.minY < scrollFrame.maxY else { return scrollFrame }
    var visible = scrollFrame
    visible.size.height = max(0, keyboardFrame.minY - scrollFrame.minY)
    return visible
  }

  /// Vertical drag that moves the field toward the middle of the visible area. Capped below half its
  /// height so a drag starting from the middle never leaves the scroll view.
  static func dragOffset(toReveal fieldFrame: CGRect, in visible: CGRect) -> CGFloat {
    let limit = visible.height * 0.4
    return min(limit, max(-limit, visible.midY - fieldFrame.midY))
  }

  func acceptTerms(file: StaticString = #filePath, line: UInt = #line) {
    // Scroll down to reveal the terms checkbox if it's below the fold
    app.scrollViews.firstMatch.swipeUp()
    guard termsCheckbox.waitForExistence(timeout: 10) else {
      XCTFail("Terms checkbox not found on the signup form", file: file, line: line)
      return
    }
    termsCheckbox.tap()
  }
}
