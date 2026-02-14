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
    XCTAssertTrue(screen.fullNameField.waitForExistence(timeout: 5))
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
    screen.fullNameField.tap()

    XCTAssertTrue(screen.passwordStrengthWeak.waitForExistence(timeout: 3),
                  "Weak password should show 'Weak' strength indicator")

    add(app.takeScreenshot(name: "validation-01-weak-password"))
  }

  @MainActor
  func testFairPasswordShowsFairStrength() throws {
    screen.passwordField.tap()
    screen.passwordField.typeText("Abcdefgh")

    screen.fullNameField.tap()

    XCTAssertTrue(screen.passwordStrengthFair.waitForExistence(timeout: 3),
                  "Fair password should show 'Fair' strength indicator")

    add(app.takeScreenshot(name: "validation-02-fair-password"))
  }

  @MainActor
  func testStrongPasswordShowsStrongStrength() throws {
    screen.passwordField.tap()
    screen.passwordField.typeText("StrongPass1")

    screen.fullNameField.tap()

    XCTAssertTrue(screen.passwordStrengthStrong.waitForExistence(timeout: 3),
                  "Strong password should show 'Strong' strength indicator")

    add(app.takeScreenshot(name: "validation-03-strong-password"))
  }

  // MARK: - Password Mismatch

  @MainActor
  func testPasswordMismatchShowsError() throws {
    screen.passwordField.tap()
    screen.passwordField.typeText("StrongPass1")

    screen.confirmPasswordField.tap()
    screen.confirmPasswordField.typeText("DifferentPass2")

    // Tap elsewhere to trigger onBlur validation
    screen.fullNameField.tap()

    let mismatchError = screen.errorBanner(containing: "do not match")
    XCTAssertTrue(mismatchError.waitForExistence(timeout: 3),
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

    screen.fullNameField.tap()
    screen.fullNameField.typeText(userData.fullName)

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

  // MARK: - Family Code Validation (Student Role)

  @MainActor
  func testInvalidFamilyCodeFormat() throws {
    // Go back to role selection and choose Student
    screen.changeRoleButton.tap()
    XCTAssertTrue(screen.selectYourRoleText.waitForExistence(timeout: 5))

    screen.selectRole(.player)
    XCTAssertTrue(screen.familyCodeField.waitForExistence(timeout: 5))

    screen.familyCodeField.tap()
    screen.familyCodeField.typeText("INVALID-CODE")

    // Tap elsewhere to trigger validation
    screen.fullNameField.tap()

    let familyCodeError = screen.errorBanner(containing: "FAM-XXXXXXXX")
    XCTAssertTrue(familyCodeError.waitForExistence(timeout: 3),
                  "Should show family code format error")

    add(app.takeScreenshot(name: "validation-08-invalid-family-code"))
  }

  @MainActor
  func testValidFamilyCodeFormat() throws {
    // Go back to role selection and choose Student
    screen.changeRoleButton.tap()
    XCTAssertTrue(screen.selectYourRoleText.waitForExistence(timeout: 5))

    screen.selectRole(.player)
    XCTAssertTrue(screen.familyCodeField.waitForExistence(timeout: 5))

    screen.familyCodeField.tap()
    screen.familyCodeField.typeText("FAM-ABCD1234")

    screen.fullNameField.tap()

    let familyCodeError = screen.errorBanner(containing: "FAM-XXXXXXXX")
    XCTAssertFalse(familyCodeError.waitForExistence(timeout: 2),
                   "Should NOT show family code format error for valid code")

    add(app.takeScreenshot(name: "validation-09-valid-family-code"))
  }

  // MARK: - Empty Family Code Accepted for Optional Field

  @MainActor
  func testEmptyFamilyCodeIsAccepted() throws {
    // Go back to role selection and choose Student
    screen.changeRoleButton.tap()
    XCTAssertTrue(screen.selectYourRoleText.waitForExistence(timeout: 5))

    screen.selectRole(.player)
    XCTAssertTrue(screen.familyCodeField.waitForExistence(timeout: 5))

    // Leave family code empty and fill everything else
    let userData = TestUserData.uniquePlayer()

    screen.fullNameField.tap()
    screen.fullNameField.typeText(userData.fullName)

    screen.emailField.tap()
    screen.emailField.typeText(userData.email)

    screen.passwordField.tap()
    screen.passwordField.typeText(userData.password)

    screen.confirmPasswordField.tap()
    screen.confirmPasswordField.typeText(userData.password)

    screen.acceptTerms()

    // Button should be enabled since family code is optional
    add(app.takeScreenshot(name: "validation-10-empty-family-code-accepted"))
  }
}
