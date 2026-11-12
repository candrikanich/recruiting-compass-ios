import XCTest

/// UI tests that hand-build their launch arguments skip `E2ETestEnvironment`, so the app falls back to the
/// committed generated config, which is production (ios #434). These checks keep every UI test on the local stack.
final class UITestLaunchConfigGuardTests: XCTestCase {
  /// Launches the bare app without `--uitesting` and performs no network actions.
  private static let launchOnlyAllowlist: Set<String> = ["TheRecruitingCompassUITestsLaunchTests.swift"]

  private static let uiTestsDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("TheRecruitingCompassUITests")

  private func swiftSources() throws -> [(name: String, text: String)] {
    let enumerator = try XCTUnwrap(
      FileManager.default.enumerator(at: Self.uiTestsDirectory, includingPropertiesForKeys: nil)
    )
    let urls = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    XCTAssertFalse(urls.isEmpty, "No UI test sources found at \(Self.uiTestsDirectory.path)")
    return try urls.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
  }

  func testEveryUITestThatCreatesAnAppConfiguresTheE2EEnvironment() throws {
    let offenders = try swiftSources()
      .filter { $0.text.contains("XCUIApplication()") }
      .filter { !Self.launchOnlyAllowlist.contains($0.name) }
      .filter { !$0.text.contains("E2ETestEnvironment.configure(") }
      .map(\.name)
    XCTAssertEqual(offenders, [], "UI tests must call E2ETestEnvironment.configure(app) so they never reach prod")
  }

  func testNoUITestHandBuildsTheUITestingLaunchArgument() throws {
    let offenders = try swiftSources()
      .filter { $0.name != "E2ETestEnvironment.swift" }
      .filter { source in
        source.text.split(separator: "\n").contains { line in
          line.contains("\"--uitesting\"") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
      }
      .map(\.name)
    XCTAssertEqual(offenders, [], "Launch args come from E2ETestEnvironment.configure(app), not hand-rolled arrays")
  }
}
