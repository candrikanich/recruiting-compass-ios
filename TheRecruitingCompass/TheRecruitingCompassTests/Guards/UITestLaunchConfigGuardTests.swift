import XCTest

/// UI tests that hand-build their launch arguments or environment skip `E2ETestEnvironment`, so the app falls back
/// to the committed generated config, which is production (ios #434). These checks keep every UI test on the local stack.
final class UITestLaunchConfigGuardTests: XCTestCase {
  /// Launch-config problems found in one UI test source, one message per problem.
  static func violations(in source: String) -> [String] {
    let code = source.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
      .joined(separator: "\n")

    var found: [String] = []
    let appCount = code.components(separatedBy: "XCUIApplication(").count - 1
    let configureCount = code.components(separatedBy: "E2ETestEnvironment.configure(").count - 1
    if appCount > configureCount {
      found.append("\(appCount) XCUIApplication(...) but \(configureCount) E2ETestEnvironment.configure(...)")
    }
    if code.contains("\"--uitesting\"") {
      found.append("hand-built \"--uitesting\" launch argument")
    }
    for property in ["launchArguments", "launchEnvironment"]
    where code.range(of: "\\b\(property)\\s*=[^=]", options: .regularExpression) != nil {
      found.append("whole-value \(property) assignment (use append / subscript after configure)")
    }
    return found
  }

  private static let uiTestsDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("TheRecruitingCompassUITests")

  func testEveryUITestSourceConfiguresEachAppThroughTheE2EEnvironment() throws {
    let enumerator = try XCTUnwrap(
      FileManager.default.enumerator(at: Self.uiTestsDirectory, includingPropertiesForKeys: nil)
    )
    let urls = enumerator.compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" && $0.lastPathComponent != "E2ETestEnvironment.swift" }
    XCTAssertFalse(urls.isEmpty, "No UI test sources found at \(Self.uiTestsDirectory.path)")

    let offenders = try urls.sorted { $0.path < $1.path }.compactMap { url -> String? in
      let problems = Self.violations(in: try String(contentsOf: url, encoding: .utf8))
      return problems.isEmpty ? nil : "\(url.lastPathComponent): \(problems.joined(separator: "; "))"
    }
    XCTAssertEqual(offenders, [], "UI tests must launch through E2ETestEnvironment.configure(app) so they never reach prod")
  }

  // MARK: - The checker itself, on synthetic sources

  func testCleanSourcePasses() {
    let source = """
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launchArguments.append("--local-captcha-bypass")
    app.launchEnvironment["API_BASE_URL"] = "http://localhost:3003"
    """
    XCTAssertEqual(Self.violations(in: source), [])
  }

  func testFlagsSecondUnconfiguredAppInConfiguredFile() {
    let source = """
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    let other = XCUIApplication()
    other.launch()
    """
    XCTAssertFalse(Self.violations(in: source).isEmpty)
  }

  func testFlagsLaunchArgumentsReassignedAfterConfigure() {
    let source = """
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launchArguments = ["--disable-animations"]
    """
    XCTAssertFalse(Self.violations(in: source).isEmpty)
  }

  func testFlagsLaunchEnvironmentReassignedAfterConfigure() {
    let source = """
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    app.launchEnvironment = ["FOO": "bar"]
    """
    XCTAssertFalse(Self.violations(in: source).isEmpty)
  }

  func testFlagsBundleIdentifierInitializer() {
    XCTAssertFalse(Self.violations(in: "let app = XCUIApplication(bundleIdentifier: \"com.example\")").isEmpty)
  }

  func testFlagsConfiguredAndUnconfiguredHelpersInOneFile() {
    let source = """
    func makeLocalApp() -> XCUIApplication {
      let app = XCUIApplication()
      E2ETestEnvironment.configure(app)
      return app
    }
    func makeBareApp() -> XCUIApplication { XCUIApplication() }
    """
    XCTAssertFalse(Self.violations(in: source).isEmpty)
  }

  func testFlagsAConfigureThatIsNotTheE2EEnvironment() {
    let source = """
    app = XCUIApplication()
    SomethingElse.configure(app)
    """
    XCTAssertFalse(Self.violations(in: source).isEmpty)
  }

  func testFlagsHandBuiltUITestingArgument() {
    let source = """
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    let args = ["--uitesting"]
    """
    XCTAssertFalse(Self.violations(in: source).isEmpty)
  }

  func testIgnoresCommentedOutCode() {
    let source = """
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    // app.launchArguments = ["--uitesting"]
    """
    XCTAssertEqual(Self.violations(in: source), [])
  }
}
