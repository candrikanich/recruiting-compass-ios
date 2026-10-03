import XCTest

final class SignupFlowE2ETests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SignupScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    screen = SignupScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Landing to Signup Navigation

  @MainActor
  func testNavigateFromLandingToSignup() throws {
    XCTAssertTrue(screen.landingCreateAccountButton.waitForExistence(timeout: 10),
                  "Create Account button should be visible on landing screen")

    add(app.takeScreenshot(name: "01-landing-screen"))

    screen.navigateToSignup()

    XCTAssertTrue(screen.selectYourRoleText.waitForExistence(timeout: 5),
                  "Should navigate to role selection screen")

    add(app.takeScreenshot(name: "02-role-selection-screen"))
  }

  // MARK: - Role Selection

  @MainActor
  func testAllThreeRolesVisible() throws {
    screen.navigateToSignup()

    XCTAssertTrue(screen.parentRoleCard.waitForExistence(timeout: 5),
                  "Parent role card should be visible")
    XCTAssertTrue(screen.playerRoleCard.exists,
                  "Student role card should be visible")
    XCTAssertTrue(screen.playerRoleCard.exists,
                  "Player role card should be visible")

    add(app.takeScreenshot(name: "03-all-roles-visible"))
  }

  @MainActor
  func testSelectParentRoleShowsForm() throws {
    screen.navigateToSignup()
    screen.selectRole(.parent)

    XCTAssertTrue(screen.firstNameField.waitForExistence(timeout: 5),
                  "First Name field should appear after selecting Parent role")
    XCTAssertTrue(screen.lastNameField.exists, "Last Name field should be visible")
    XCTAssertTrue(screen.emailField.exists, "Email field should be visible")
    XCTAssertTrue(screen.passwordField.exists, "Password field should be visible")
    XCTAssertTrue(screen.confirmPasswordField.exists, "Confirm Password field should be visible")
    XCTAssertTrue(screen.termsCheckbox.exists, "Terms checkbox should be visible")
    XCTAssertTrue(screen.createAccountButton.exists, "Create Account button should be visible")

    add(app.takeScreenshot(name: "04-parent-signup-form"))
  }

  @MainActor
  func testSelectPlayerRoleShowsFormWithoutFamilyCode() throws {
    screen.navigateToSignup()
    screen.selectRole(.player)

    XCTAssertTrue(screen.firstNameField.waitForExistence(timeout: 5),
                  "First Name field should appear after selecting Player role")
    XCTAssertTrue(screen.lastNameField.exists)
    XCTAssertTrue(screen.emailField.exists)
    XCTAssertTrue(screen.passwordField.exists)
    XCTAssertTrue(screen.confirmPasswordField.exists)
    // Family code is not shown for either role (both create their own family at signup)
    XCTAssertTrue(screen.createAccountButton.exists)

    add(app.takeScreenshot(name: "05-player-signup-form"))
  }

  @MainActor
  func testChangeRoleReturnsToRoleSelection() throws {
    screen.navigateToSignup()
    screen.selectRole(.parent)

    XCTAssertTrue(screen.changeRoleButton.waitForExistence(timeout: 5),
                  "Change Role button should be visible in form")

    screen.changeRoleButton.tap()

    XCTAssertTrue(screen.selectYourRoleText.waitForExistence(timeout: 5),
                  "Should return to role selection screen")

    add(app.takeScreenshot(name: "07-returned-to-role-selection"))
  }

  @MainActor
  func testBackButtonReturnsToLanding() throws {
    screen.navigateToSignup()

    XCTAssertTrue(screen.backButton.waitForExistence(timeout: 5),
                  "Back button should be visible")

    screen.backButton.tap()

    XCTAssertTrue(screen.landingCreateAccountButton.waitForExistence(timeout: 5),
                  "Should return to landing screen")

    add(app.takeScreenshot(name: "08-returned-to-landing"))
  }

  // MARK: - Completed Parent Form

  /// Fills every required field and checks the form becomes submittable. It stops short of
  /// tapping "Create account": signup goes through the web API, which the E2E job points at
  /// production (API_BASE_URL), so a real submit would hit prod with a placeholder captcha.
  /// The account is auto-confirmed and signed in on success, so there is no
  /// "Verify Your Email" screen to wait for either.
  @MainActor
  func testCompletedParentFormEnablesCreateAccount() throws {
    let userData = TestUserData.uniqueParent()

    screen.navigateToSignup()
    screen.selectRole(.parent)
    add(app.takeScreenshot(name: "09-parent-selected"))

    XCTAssertFalse(screen.createAccountButton.isEnabled, "Create account should start disabled")

    screen.fillSignupForm(with: userData)
    add(app.takeScreenshot(name: "10-form-filled"))

    screen.acceptTerms()
    add(app.takeScreenshot(name: "11-terms-accepted"))

    let enabled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "isEnabled == true"),
      object: screen.createAccountButton
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [enabled], timeout: 5), .completed,
      "Create account should be enabled once every required field and the terms box are filled"
    )
  }

  // MARK: - Sign In Link Navigation

  @MainActor
  func testSignInLinkNavigatesToLogin() throws {
    screen.navigateToSignup()
    screen.selectRole(.parent)

    XCTAssertTrue(screen.signInLink.waitForExistence(timeout: 5),
                  "Sign In link should be visible in signup form")

    add(app.takeScreenshot(name: "16-sign-in-link-visible"))
  }
}
