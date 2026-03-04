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
    app.buttons["Create a new account"]
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

  /// Signup form fields use combined accessibility (label+field); find by identifier.
  var firstNameField: XCUIElement {
    app.otherElements["First Name"].firstMatch
  }

  var lastNameField: XCUIElement {
    app.otherElements["Last Name"].firstMatch
  }

  var emailField: XCUIElement {
    app.otherElements["Email"].firstMatch
  }

  var passwordField: XCUIElement {
    // LoginFormField uses .accessibilityElement(children: .combine), so the outer
    // container is Other type with identifier "Password". Try to get the inner
    // SecureField for typing; fall back to the container.
    let container = app.otherElements.matching(identifier: "Password").firstMatch
    let inner = container.secureTextFields.firstMatch
    return inner.exists ? inner : container
  }

  var confirmPasswordField: XCUIElement {
    let container = app.otherElements.matching(identifier: "Confirm Password").firstMatch
    let inner = container.secureTextFields.firstMatch
    return inner.exists ? inner : container
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

  var createAccountLoadingButton: XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "label == 'Creating account, please wait'")
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

  // MARK: - Email Verification Screen Elements

  var verifyYourEmailHeadline: XCUIElement {
    // Headlines may be combined with subtitles using .accessibilityElement(children: .combine)
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS 'Verify Your Email'")
    ).firstMatch
  }

  var verifiedHeadline: XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS 'Verified!'")
    ).firstMatch
  }

  var continueButton: XCUIElement {
    app.buttons["Continue to dashboard"]
  }

  var resendButton: XCUIElement {
    app.buttons["Resend verification email"]
  }

  var resendCooldownText: XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS 'Resend available in'")
    ).firstMatch
  }

  // MARK: - Dashboard Elements

  var dashboardWelcomeText: XCUIElement {
    // Dashboard text may also be combined elements
    app.descendants(matching: .any).matching(
      NSPredicate(format: "label == 'Welcome!'")
    ).firstMatch
  }

  var logoutButton: XCUIElement {
    app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Log Out'")
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

  func fillSignupForm(with data: TestUserData) {
    let nameParts = data.fullName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    let first = nameParts.first.map(String.init) ?? data.fullName
    let last = nameParts.count > 1 ? String(nameParts[1]) : ""

    guard firstNameField.waitForExistence(timeout: 10) else { return }
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

  func acceptTerms() {
    // Scroll down to reveal the terms checkbox if it's below the fold
    app.scrollViews.firstMatch.swipeUp()
    guard termsCheckbox.waitForExistence(timeout: 10) else { return }
    termsCheckbox.tap()
  }

  func submitSignup() {
    guard createAccountButton.waitForExistence(timeout: 10) else { return }
    createAccountButton.tap()
  }

  func performFullParentSignup(with data: TestUserData) {
    navigateToSignup()
    selectRole(data.role)
    fillSignupForm(with: data)
    acceptTerms()
    submitSignup()
  }
}
