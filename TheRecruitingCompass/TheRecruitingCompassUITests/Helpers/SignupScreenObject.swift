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

  var fullNameField: XCUIElement {
    app.textFields["Full Name"]
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
    app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS[cd] %@", text)
    ).firstMatch
  }

  var passwordStrengthWeak: XCUIElement {
    app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS 'Password strength: Weak'")
    ).firstMatch
  }

  var passwordStrengthFair: XCUIElement {
    app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS 'Password strength: Fair'")
    ).firstMatch
  }

  var passwordStrengthStrong: XCUIElement {
    app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS 'Password strength: Strong'")
    ).firstMatch
  }

  // MARK: - Email Verification Screen Elements

  var verifyYourEmailHeadline: XCUIElement {
    app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS 'Verify Your Email'")
    ).firstMatch
  }

  var verifiedHeadline: XCUIElement {
    app.staticTexts.matching(
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
    app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS 'Resend available in'")
    ).firstMatch
  }

  // MARK: - Dashboard Elements

  var dashboardWelcomeText: XCUIElement {
    app.staticTexts["Welcome!"]
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
    case .student:
      studentRoleCard.waitAndTap()
    case .player:
      playerRoleCard.waitAndTap()
    }
  }

  func fillSignupForm(with data: TestUserData) {
    fullNameField.waitAndTap()
    fullNameField.typeText(data.fullName)

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
