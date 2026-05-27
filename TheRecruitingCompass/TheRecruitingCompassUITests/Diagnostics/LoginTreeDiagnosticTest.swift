import XCTest

/// Throwaway diagnostic: drives to the login screen and dumps the XCUI element
/// tree so we can see the exact queryable identifiers/types for the email,
/// password, and submit controls. Delete once the login helper selectors are fixed.
final class LoginTreeDiagnosticTest: XCTestCase {
  func testDumpLoginTree() throws {
    let app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    let signIn = app.buttons["Sign in to your account"]
    XCTAssertTrue(signIn.waitForExistence(timeout: 10), "landing sign-in not found")
    signIn.tap()

    // Give the login screen a moment to render.
    _ = app.staticTexts.firstMatch.waitForExistence(timeout: 5)

    print("=====LOGIN_TREE_START=====")
    print(app.debugDescription)
    print("=====LOGIN_TREE_END=====")
  }
}
