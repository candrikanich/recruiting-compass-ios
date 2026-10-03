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
    firstNameField.tap()
    firstNameField.typeText(first)

    if !last.isEmpty {
      lastNameField.tap()
      lastNameField.typeText(last)
    }

    emailField.tap()
    emailField.typeText(data.email)

    passwordField.tap()
    passwordField.typeText(data.password)

    confirmPasswordField.tap()
    confirmPasswordField.typeText(data.password)

    if let familyCode = data.familyCode, familyCodeField.waitForExistence(timeout: 1) {
      familyCodeField.tap()
      familyCodeField.typeText(familyCode)
    }
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
