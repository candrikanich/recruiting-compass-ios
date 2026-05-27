import XCTest

/// Throwaway diagnostic: drives to the login screen, attaches the XCUI element
/// tree, and probes candidate selectors so the failure log names which ones
/// resolve. Delete once the login helper selectors are fixed.
final class LoginTreeDiagnosticTest: XCTestCase {
  func testDumpLoginTree() throws {
    let app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launch()

    let signIn = app.buttons["Sign in to your account"]
    XCTAssertTrue(signIn.waitForExistence(timeout: 10), "landing sign-in not found")
    signIn.tap()
    _ = app.staticTexts.firstMatch.waitForExistence(timeout: 5)

    let tree = app.debugDescription
    let attachment = XCTAttachment(string: tree)
    attachment.name = "login-tree"
    attachment.lifetime = .keepAlways
    add(attachment)

    // Probe candidate selectors. Each failing assertion names a selector that
    // does NOT resolve; passing ones are silent — so the failure list is the
    // set of selectors to avoid.
    func probe(_ exists: Bool, _ desc: String) {
      XCTAssertFalse(exists, "PROBE_EXISTS: \(desc)")
    }
    probe(app.textFields["Email"].exists, "textFields[Email]")
    probe(app.secureTextFields["Password"].exists, "secureTextFields[Password]")
    probe(app.otherElements["Email"].exists, "otherElements[Email]")
    probe(app.otherElements["Password"].exists, "otherElements[Password]")
    probe(app.buttons["Sign in"].exists, "buttons[Sign in]")
    probe(app.buttons["Sign in to account"].exists, "buttons[Sign in to account]")
    probe(app.textFields.count > 0, "ANY textFields (count=\(app.textFields.count))")
    probe(app.secureTextFields.count > 0, "ANY secureTextFields (count=\(app.secureTextFields.count))")
  }
}
