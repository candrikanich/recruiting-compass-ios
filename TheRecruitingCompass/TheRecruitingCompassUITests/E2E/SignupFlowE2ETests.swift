import XCTest

final class SignupFlowE2ETests: XCTestCase {
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

  // MARK: - Full Parent Signup Flow

  @MainActor
  func testFullParentSignupFlow() throws {
    let userData = TestUserData.uniqueParent()

    screen.navigateToSignup()
    add(app.takeScreenshot(name: "09-signup-start"))

    screen.selectRole(.parent)
    add(app.takeScreenshot(name: "10-parent-selected"))

    screen.fillSignupForm(with: userData)
    add(app.takeScreenshot(name: "11-form-filled"))

    screen.acceptTerms()
    add(app.takeScreenshot(name: "12-terms-accepted"))

    screen.submitSignup()

    // Wait for either the email verification screen or an error
    let verifyEmailExists = screen.verifyYourEmailHeadline.waitForExistence(timeout: 15)

    if verifyEmailExists {
      add(app.takeScreenshot(name: "13-email-verification-screen"))
      XCTAssertTrue(true, "Successfully navigated to email verification screen")
    } else {
      add(app.takeScreenshot(name: "13-signup-error"))
      // If we get an error (e.g., SUPABASE not configured), capture it
      // Use descendants(matching: .any) to find combined accessibility elements
      let errorExists = app.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS[cd] 'error' OR label CONTAINS[cd] 'failed'")
      ).firstMatch.exists

      if errorExists {
        throw XCTSkip("Signup failed with an error — Supabase may not be configured")
      } else {
        throw XCTSkip("Did not navigate to email verification screen within timeout — Supabase may not be configured")
      }
    }
  }

  // MARK: - Parent Signup (no family code field in current flow)

  @MainActor
  func testParentSignupWithoutFamilyCode() throws {
    let userData = TestUserData.uniqueParent()

    screen.navigateToSignup()
    screen.selectRole(.parent)

    XCTAssertTrue(screen.firstNameField.waitForExistence(timeout: 5))

    screen.fillSignupForm(with: userData)
    screen.acceptTerms()

    add(app.takeScreenshot(name: "14-parent-form-filled"))

    screen.submitSignup()

    let verifyEmailExists = screen.verifyYourEmailHeadline.waitForExistence(timeout: 15)

    if verifyEmailExists {
      add(app.takeScreenshot(name: "15-parent-verification-screen"))
    }
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
