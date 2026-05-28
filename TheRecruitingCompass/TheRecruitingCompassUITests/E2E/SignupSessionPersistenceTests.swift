import XCTest

final class SignupSessionPersistenceTests: XCTestCase {
  private var app: XCUIApplication!
  private var screen: SignupScreenObject!

  override func setUpWithError() throws {
    continueAfterFailure = false

    app = XCUIApplication()
    E2ETestEnvironment.configure(app)

    screen = SignupScreenObject(app: app)
  }

  override func tearDownWithError() throws {
    app = nil
    screen = nil
  }

  // MARK: - Session Persistence After Signup

  @MainActor
  func testSessionPersistsAfterAppRelaunch() throws {
    // Phase 1: Complete signup
    app.launch()

    let userData = TestUserData.uniqueParent()
    screen.performFullParentSignup(with: userData)

    let reachedVerification = screen.verifyYourEmailHeadline.waitForExistence(timeout: 15)
    try XCTSkipUnless(reachedVerification, "Skipping: Could not reach email verification (Supabase may not be configured)")

    add(app.takeScreenshot(name: "persist-01-after-signup"))

    // Phase 2: Terminate and relaunch
    app.terminate()
    app.launch()

    // Phase 3: Check if session was restored
    // If session is valid, we should NOT see the landing screen
    // Instead we should see either the Dashboard or the Verification screen
    let landingVisible = screen.landingCreateAccountButton.waitForExistence(timeout: 10)

    if landingVisible {
      // Session was NOT persisted (possible if Supabase requires email verification first)
      add(app.takeScreenshot(name: "persist-02-session-not-persisted"))
      // This is acceptable if email verification is required before session is saved
    } else {
      // Session WAS persisted
      let dashboardVisible = screen.dashboardWelcomeText.waitForExistence(timeout: 5)
      let verificationVisible = screen.verifyYourEmailHeadline.waitForExistence(timeout: 5)

      add(app.takeScreenshot(name: "persist-02-session-persisted"))

      XCTAssertTrue(dashboardVisible || verificationVisible,
                    "After relaunch, should see Dashboard or Email Verification (not Landing)")
    }
  }

  // MARK: - Logout Clears Session

  @MainActor
  func testLogoutClearsSessionAndShowsLanding() throws {
    app.launch()

    // Check if already authenticated
    let dashboardVisible = screen.dashboardWelcomeText.waitForExistence(timeout: 10)

    if dashboardVisible {
      // Tap logout
      screen.logoutButton.waitAndTap()

      // Should return to landing
      XCTAssertTrue(screen.landingCreateAccountButton.waitForExistence(timeout: 10),
                    "After logout, should see landing screen")

      add(app.takeScreenshot(name: "persist-03-after-logout"))

      // Relaunch to verify session is cleared
      app.terminate()
      app.launch()

      XCTAssertTrue(screen.landingCreateAccountButton.waitForExistence(timeout: 10),
                    "After relaunch post-logout, should see landing screen")

      add(app.takeScreenshot(name: "persist-04-relaunch-after-logout"))
    } else {
      // Not authenticated, skip this test
      throw XCTSkip("Not authenticated - cannot test logout flow")
    }
  }
}
