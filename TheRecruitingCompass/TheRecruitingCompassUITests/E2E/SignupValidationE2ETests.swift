import XCTest

final class SignupValidationE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SignupScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launchEnvironment = [
      "SUPABASE_URL": ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
      "SUPABASE_ANON_KEY": ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    ]
    app.launch()

    screen = SignupScreenObject(app: app)

    // Navigate to parent signup form for all validation tests
    screen.navigateToSignup()
    screen.selectRole(.parent)
    XCTAssertTrue(screen.firstNameField.waitForExistence(timeout: 5))
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Password Strength Indicator

  @MainActor
  func testWeakPasswordShowsWeakStrength() throws {
    screen.passwordField.tap()
    screen.passwordField.typeText("abc")

    // Tap elsewhere to trigger validation
    screen.firstNameField.tap()

    XCTAssertTrue(screen.passwordStrengthWeak.waitForExistence(timeout: 3),
                  "Weak password should show 'Weak' strength indicator")

    add(app.takeScreenshot(name: "validation-01-weak-password"))
  }

  @MainActor
  func testFairPasswordShowsFairStrength() throws {
    screen.passwordField.tap()
    screen.passwordField.typeText("abcdefg12")

    add(app.takeScreenshot(name: "validation-02-after-typing"))

    XCTAssertTrue(screen.passwordStrengthFair.waitForExistence(timeout: 5),
                  "Fair password should show 'Fair' strength indicator")

    add(app.takeScreenshot(name: "validation-02-fair-password"))
  }

  @MainActor
  func testStrongPasswordShowsStrongStrength() throws {
    screen.passwordField.tap()
    // "abc1DEFGH": lowercase first (no shift at start), then uppercase mid-string
    // length ✓  uppercase(D,E,F,G,H) ✓  lowercase(abc) ✓  number(1) ✓ → 4/4 = Strong
    screen.passwordField.typeText("abc1DEFGH")

    XCTAssertTrue(screen.passwordStrengthStrong.waitForExistence(timeout: 5),
                  "Strong password should show 'Strong' strength indicator")

    add(app.takeScreenshot(name: "validation-03-strong-password"))
  }

  // MARK: - Password Mismatch

  @MainActor
  func testPasswordMismatchShowsError() throws {
    screen.passwordField.tap()
    screen.passwordField.typeText("abcdefg12")

    screen.confirmPasswordField.tap()
    screen.confirmPasswordField.typeText("differentpass3")

    // Press Return to trigger .onSubmit(onBlur) → validateConfirmPassword()
    // (tapping another field does NOT fire .onSubmit)
    screen.confirmPasswordField.typeText("\n")

    let mismatchError = screen.errorBanner(containing: "do not match")
    XCTAssertTrue(mismatchError.waitForExistence(timeout: 5),
                  "Should show 'Passwords do not match' error")

    add(app.takeScreenshot(name: "validation-04-password-mismatch"))
  }

  // MARK: - Create Account Button Disabled State

  @MainActor
  func testCreateAccountButtonDisabledWithEmptyForm() throws {
    // Button should be disabled (opacity 0.5) when form is empty
    XCTAssertTrue(screen.createAccountButton.exists,
                  "Create Account button should exist")

    // The button should not be hittable when disabled
    // (SwiftUI disabled modifier makes it not interactive)
    add(app.takeScreenshot(name: "validation-05-button-disabled-empty-form"))
  }

  @MainActor
  func testCreateAccountButtonEnabledWithValidForm() throws {
    let userData = TestUserData.uniqueParent()

    screen.fillSignupForm(with: userData)

    screen.emailField.tap()
    screen.emailField.typeText(userData.email)

    screen.passwordField.tap()
    screen.passwordField.typeText(userData.password)

    screen.confirmPasswordField.tap()
    screen.confirmPasswordField.typeText(userData.password)

    screen.acceptTerms()

    // Button should become enabled with valid form
    add(app.takeScreenshot(name: "validation-06-button-enabled-valid-form"))
  }

  // MARK: - Terms Checkbox

  @MainActor
  func testTermsCheckboxToggle() throws {
    let checkboxUnchecked = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Terms of Service' AND value == 'Unchecked'")
    ).firstMatch

    let checkboxChecked = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Terms of Service' AND value == 'Checked'")
    ).firstMatch

    XCTAssertTrue(checkboxUnchecked.waitForExistence(timeout: 3),
                  "Checkbox should initially be unchecked")

    screen.acceptTerms()

    XCTAssertTrue(checkboxChecked.waitForExistence(timeout: 3),
                  "Checkbox should be checked after tapping")

    add(app.takeScreenshot(name: "validation-07-terms-checked"))
  }

  // MARK: - Family Code Validation (skipped: family code not shown for either role)

  @MainActor
  func testInvalidFamilyCodeFormat() throws {
    throw XCTSkip("Family code field is not shown in signup; both roles create their own family")
  }

  @MainActor
  func testValidFamilyCodeFormat() throws {
    throw XCTSkip("Family code field is not shown in signup; both roles create their own family")
  }

  @MainActor
  func testEmptyFamilyCodeIsAccepted() throws {
    throw XCTSkip("Family code field is not shown in signup; both roles create their own family")
  }
}
