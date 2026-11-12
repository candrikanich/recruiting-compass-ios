import XCTest

/// UI tests that hand-build their launch arguments or environment skip `E2ETestEnvironment`, so the app falls back
/// to the committed generated config, which is production (ios #434). These checks keep every UI test on the local stack.
final class UITestLaunchConfigGuardTests: XCTestCase {
  /// Launch-config problems found in one UI test source, one message per problem.
  ///
  /// Counting is per file, so a file that configures twice for one app can still hide an unconfigured second app.
  static func violations(in source: String) -> [String] {
    let code = strippingComments(from: source)

    var found: [String] = []
    let appCount = matchCount(of: "XCUIApplication(\\.init)?\\(|=\\s*\\.init\\(", in: code)
    let configureCount = matchCount(of: "E2ETestEnvironment\\.configure\\(", in: code)
    if appCount > configureCount {
      found.append("\(appCount) XCUIApplication constructions but \(configureCount) E2ETestEnvironment.configure(...)")
    }
    if code.contains("\"--uitesting\"") {
      found.append("hand-built \"--uitesting\" launch argument")
    }
    for property in ["launchArguments", "launchEnvironment"] {
      if matchCount(of: "\\b\(property)\\s*=[^=]", in: code) > 0 {
        found.append("whole-value \(property) assignment (use append / subscript after configure)")
      }
      if matchCount(of: "\\b\(property)\\.removeAll", in: code) > 0 {
        found.append("\(property).removeAll drops what configure set")
      }
    }
    return found
  }

  private static func matchCount(of pattern: String, in text: String) -> Int {
    // Swift Regex defaults to Unicode word boundaries, which treat `.launchArguments` oddly; `.simple` is ASCII-style.
    text.ranges(of: try! Regex(pattern).wordBoundaryKind(.simple)).count
  }

  /// Drops block comments (multi-line too) and end-of-line comments; `://` in URLs is left alone.
  private static func strippingComments(from source: String) -> String {
    source
      .replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)
      .replacingOccurrences(of: "(?<!:)//.*", with: "", options: .regularExpression)
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

  func testDoesNotFlagIdentifiersThatMerelyEndInLaunchArguments() {
    let source = "app = XCUIApplication()\nE2ETestEnvironment.configure(app)\nlet relaunchArguments = [\"-x\"]"
    XCTAssertEqual(Self.violations(in: source), [])
  }

  func testIgnoresCommentedOutCode() {
    let source = """
    app = XCUIApplication()
    E2ETestEnvironment.configure(app)
    // app.launchArguments = ["--uitesting"]
    """
    XCTAssertEqual(Self.violations(in: source), [])
  }

  func testFlagsInitFormConstructions() {
    XCTAssertFalse(Self.violations(in: "let app: XCUIApplication = .init()").isEmpty)
    XCTAssertFalse(Self.violations(in: "let app = XCUIApplication.init()").isEmpty)
    XCTAssertFalse(Self.violations(in: "private var app: XCUIApplication!\napp = .init()").isEmpty)
  }

  func testIgnoresConfigureInsideBlockComments() {
    let single = "app = XCUIApplication()\n/* E2ETestEnvironment.configure(app) */"
    let multi = "app = XCUIApplication()\n/*\n E2ETestEnvironment.configure(app)\n*/"
    let trailing = "app = XCUIApplication()\nlet x = 1 // E2ETestEnvironment.configure(app)"
    for source in [single, multi, trailing] {
      XCTAssertFalse(Self.violations(in: source).isEmpty, source)
    }
  }

  func testUrlSlashesDoNotHideTheRestOfALine() {
    let source = "app = XCUIApplication()\nE2ETestEnvironment.configure(app); let u = \"http://x\"; app.launchArguments = []"
    XCTAssertFalse(Self.violations(in: source).isEmpty)
  }

  func testFlagsUITestingArgumentInAnyForm() {
    let base = "app = XCUIApplication()\nE2ETestEnvironment.configure(app)\n"
    XCTAssertFalse(Self.violations(in: base + "app.launchArguments.append(\"--uitesting\")").isEmpty)
    XCTAssertFalse(Self.violations(in: base + "app.launchArguments += [\"--x\", \"--uitesting\"]").isEmpty)
  }

  func testFlagsRemoveAllOnLaunchConfig() {
    let base = "app = XCUIApplication()\nE2ETestEnvironment.configure(app)\n"
    XCTAssertFalse(Self.violations(in: base + "app.launchArguments.removeAll()").isEmpty)
    XCTAssertFalse(Self.violations(in: base + "app.launchEnvironment.removeAll()").isEmpty)
  }
}
