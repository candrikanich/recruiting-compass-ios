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

  var firstNameField: XCUIElement {
    app.textFields["First Name"]
  }

  var lastNameField: XCUIElement {
    app.textFields["Last Name"]
  }

  var emailField: XCUIElement {
    app.textFields["Email"]
  }

  var passwordField: XCUIElement {
    app.secureTextFields["Password"]
  }

  var confirmPasswordField: XCUIElement {
    app.secureTextFields["Confirm Password"]
  }

  var familyCodeField: XCUIElement {
    app.textFields["Family Code (Optional)"]
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
    switch role {
    case .parent:
      parentRoleCard.waitAndTap()
    case .player:
      playerRoleCard.waitAndTap()
    }
  }

  func fillSignupForm(with data: TestUserData) {
    let nameParts = data.fullName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    let first = nameParts.first.map(String.init) ?? data.fullName
    let last = nameParts.count > 1 ? String(nameParts[1]) : ""

    firstNameField.waitAndTap()
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

    if let familyCode = data.familyCode {
      familyCodeField.tap()
      familyCodeField.typeText(familyCode)
    }
  }

  func acceptTerms() {
    termsCheckbox.waitAndTap()
  }

  func submitSignup() {
    createAccountButton.waitAndTap()
  }

  func performFullParentSignup(with data: TestUserData) {
    navigateToSignup()
    selectRole(data.role)
    fillSignupForm(with: data)
    acceptTerms()
    submitSignup()
  }
}
