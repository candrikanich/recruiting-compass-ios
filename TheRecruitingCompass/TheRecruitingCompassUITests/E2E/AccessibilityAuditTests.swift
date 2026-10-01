import XCTest

/// Runs Xcode's accessibility audit screen by screen and writes every issue, plus a screenshot and the
/// accessibility tree per screen, to `A11Y_AUDIT_REPORT_DIR` on the host.
/// Skipped unless `A11Y_AUDIT=1` (pass `TEST_RUNNER_A11Y_AUDIT=1` and `TEST_RUNNER_A11Y_AUDIT_REPORT_DIR=<dir>`
/// to xcodebuild). It reports known issues, so it is an audit tool rather than a CI gate.
///
/// `A11Y_AUDIT_CONFIG` names the run (`light`, `dark`, `largest-text`). Appearance is set on the host with
/// `xcrun simctl ui <udid> appearance dark` — `XCUIDevice.shared.appearance` did not take effect before launch.
///
/// The logged-out test needs no backend (the app is pointed at an unroutable Supabase URL). The signed-in test
/// needs the LOCAL Supabase stack with a seeded account in `A11Y_AUDIT_EMAIL` / `A11Y_AUDIT_PASSWORD`; it only
/// reads — it opens forms but never submits, edits, deletes or signs out.
final class AccessibilityAuditTests: XCTestCase {
  private struct RecordedIssue: Encodable {
    let configuration: String
    let screen: String
    let type: String
    let summary: String
    let detail: String
    let element: String
    let frame: String
  }

  private static let largestTextCategory = "UICTContentSizeCategoryAccessibilityXXXL"

  private var app: XCUIApplication!
  private var reportDir: URL!
  private var configuration = "light"
  private var issues: [RecordedIssue] = []

  override func setUpWithError() throws {
    continueAfterFailure = true
    let env = ProcessInfo.processInfo.environment
    try XCTSkipUnless(env["A11Y_AUDIT"] == "1", "Set A11Y_AUDIT=1 to run the accessibility audit")
    let dir = try XCTUnwrap(env["A11Y_AUDIT_REPORT_DIR"], "A11Y_AUDIT_REPORT_DIR is required")
    reportDir = URL(fileURLWithPath: dir)
    configuration = env["A11Y_AUDIT_CONFIG"] ?? "light"
    try FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    app = nil
  }

  @MainActor
  func testAuditLoggedOutScreens() throws {
    launch()
    audit("landing")

    tap(app.buttons["Sign in to your account"])
    audit("login")

    tap(app.buttons["Forgot password"])
    audit("forgot-password")

    launch()
    tap(app.buttons["Start now — create a new account"])
    audit("signup-role")

    for role in ["Player", "Parent"] {
      tap(app.buttons["\(role) role"])
      audit("signup-\(role.lowercased())")
      tap(app.buttons["Change role selection"])
    }

    try writeReport("logged-out")
  }

  @MainActor
  func testAuditSignedInScreens() throws {
    let env = ProcessInfo.processInfo.environment
    let email = try XCTUnwrap(env["A11Y_AUDIT_EMAIL"], "A11Y_AUDIT_EMAIL is required")
    let password = try XCTUnwrap(env["A11Y_AUDIT_PASSWORD"], "A11Y_AUDIT_PASSWORD is required")
    let navigator = MainTabNavigator(app: signIn(email: email, password: password))

    audit("dashboard")
    scroll(.down)
    audit("dashboard-scrolled")

    // (tab, text on a seeded row near the top of the list, whose detail screen is audited too)
    let tabs: [(MainTabNavigator.Tab, String)] = [
      (.schools, "Clemson"), (.coaches, "Kevin Brandt"), (.interactions, "Looking forward")
    ]
    for (tab, rowText) in tabs {
      let name = tab.rawValue.lowercased()
      restoreTabBar()
      guard navigator.goTo(tab) else {
        XCTFail("Could not open tab \(tab.rawValue)")
        continue
      }
      audit("\(name)-list")
      guard openRow(containing: rowText) else { continue }
      audit("\(name)-detail")
      scroll(.down)
      audit("\(name)-detail-scrolled")
      goBack()
    }

    restoreTabBar()
    navigator.goToMore()
    audit("more")
    let sections = [
      "Recruiting Timeline", "Events", "Deadlines", "Documents", "Offers", "Performance", "Analytics",
      "Activity History", "Coach Emails", "Help Center", "Public Profile", "Notifications", "Player Details"
    ]
    for section in sections {
      restoreTabBar()
      navigator.goToMore()
      // The menu is a lazy list: rows below the fold do not exist until scrolled to.
      let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", section)).firstMatch
      for _ in 0..<3 where !(row.exists && row.isHittable) {
        scroll(.down)
      }
      guard row.exists else {
        XCTFail("Could not open More section \(section)")
        continue
      }
      row.tap()
      audit(section.lowercased().replacingOccurrences(of: " ", with: "-"))
      goBack()
    }

    // Forms hide the system back button, so each gets a fresh launch instead of a way out.
    for (tab, addLabel) in [(MainTabNavigator.Tab.coaches, "Add new coach"), (.schools, "Add new school")] {
      MainTabNavigator(app: signIn(email: email, password: password)).goTo(tab)
      tap(app.buttons[addLabel])
      audit(addLabel.lowercased().replacingOccurrences(of: " ", with: "-"))
    }

    try writeReport("signed-in")
  }

  // MARK: - Helpers

  private func writeReport(_ name: String) throws {
    let data = try JSONEncoder().encode(issues)
    try data.write(to: reportDir.appendingPathComponent("issues-\(name)-\(configuration).json"))
    XCTAssertTrue(issues.isEmpty, "\(issues.count) accessibility issues — see \(reportDir.path)")
  }

  private func launch(unroutableBackend: Bool = true) {
    app?.terminate()
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    if unroutableBackend {
      app.launchEnvironment["SUPABASE_URL"] = "http://127.0.0.1:1"
    } else {
      app.launchArguments.append("--local-captcha-bypass")
    }
    if configuration == "largest-text" {
      app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.largestTextCategory]
    }
    app.launch()
    XCTAssertTrue(app.buttons["Sign in to your account"].waitForExistence(timeout: 20), "Landing did not appear")
  }

  @discardableResult
  private func signIn(email: String, password: String) -> XCUIApplication {
    launch(unroutableBackend: false)
    tap(app.buttons["Sign in to your account"])
    let emailField = app.textFields.firstMatch
    tap(emailField)
    emailField.typeText(email)
    let passwordField = app.secureTextFields.firstMatch
    tap(passwordField)
    passwordField.typeText(password)
    tap(app.buttons["Sign in to account"])
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "Sign-in failed")
    // The system save-password prompt and dismissible dashboard banners would otherwise be audited too.
    for label in ["Not Now", "Dismiss"] where app.buttons[label].waitForExistence(timeout: 4) {
      app.buttons[label].tap()
    }
    return app
  }

  private func openRow(containing text: String) -> Bool {
    let row = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    guard row.waitForExistence(timeout: 10) else {
      XCTFail("No row containing \(text)")
      return false
    }
    row.tap()
    return true
  }

  private func goBack() {
    let back = app.navigationBars.buttons.firstMatch
    if back.waitForExistence(timeout: 5) { back.tap() }
  }

  private enum ScrollDirection { case down, up }

  private func scroll(_ direction: ScrollDirection) {
    let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
    let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
    let (from, to) = direction == .down ? (low, high) : (high, low)
    from.press(forDuration: 0.05, thenDragTo: to)
  }

  /// Scrolling minimizes the tab bar to the selected tab alone; tapping that tab scrolls its root back to the
  /// top, and scrolling up from there expands the bar again.
  private func restoreTabBar() {
    let buttons = app.tabBars.buttons
    guard buttons.firstMatch.waitForExistence(timeout: 5) else { return }
    for _ in 0..<4 where buttons.count <= 1 {
      buttons.firstMatch.tap()
      Thread.sleep(forTimeInterval: 1)
      scroll(.up)
    }
  }

  private func tap(_ element: XCUIElement) {
    guard element.waitForExistence(timeout: 10) else {
      XCTFail("Missing element: \(element)")
      return
    }
    element.tap()
  }

  private func audit(_ screen: String) {
    // Let navigation transitions settle so the audit sees the destination, not a mid-animation frame.
    Thread.sleep(forTimeInterval: 1.5)
    let screenshot = app.screenshot().pngRepresentation
    try? screenshot.write(to: reportDir.appendingPathComponent("\(configuration)-\(screen).png"))
    try? app.debugDescription.write(
      to: reportDir.appendingPathComponent("\(configuration)-\(screen).txt"), atomically: true, encoding: .utf8
    )

    do {
      try app.performAccessibilityAudit { [self] issue in
        issues.append(
          RecordedIssue(
            configuration: configuration,
            screen: screen,
            type: Self.name(of: issue.auditType),
            summary: issue.compactDescription,
            detail: issue.detailedDescription,
            element: issue.element.map { "\($0.elementType.rawValue):\($0.label)|\($0.identifier)" } ?? "",
            frame: issue.element.map { "\($0.frame)" } ?? ""
          )
        )
        return true
      }
    } catch {
      XCTFail("Audit failed on \(configuration)/\(screen): \(error)")
    }
  }

  private static func name(of type: XCUIAccessibilityAuditType) -> String {
    let names: [(XCUIAccessibilityAuditType, String)] = [
      (.contrast, "contrast"),
      (.elementDetection, "elementDetection"),
      (.hitRegion, "hitRegion"),
      (.sufficientElementDescription, "sufficientElementDescription"),
      (.dynamicType, "dynamicType"),
      (.textClipped, "textClipped"),
      (.trait, "trait")
    ]
    return names.first { type.contains($0.0) }?.1 ?? "other(\(type.rawValue))"
  }
}
