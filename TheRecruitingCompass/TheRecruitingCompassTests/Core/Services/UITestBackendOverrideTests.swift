import XCTest
@testable import TheRecruitingCompass

final class UITestBackendOverrideTests: XCTestCase {
  private func resolve(isUITesting: Bool, _ environment: [String: String]) -> UITestBackendOverride {
    UITestBackendOverride.resolve("SUPABASE_URL", isUITesting: isUITesting, environment: environment)
  }

  func test_uiTesting_missingValue_failsClosedInsteadOfFallingBackToEmbeddedConfig() {
    XCTAssertEqual(resolve(isUITesting: true, [:]), .missing)
  }

  func test_uiTesting_emptyOrBlankValue_failsClosed() {
    XCTAssertEqual(resolve(isUITesting: true, ["SUPABASE_URL": ""]), .missing)
    XCTAssertEqual(resolve(isUITesting: true, ["SUPABASE_URL": "   "]), .missing)
  }

  func test_uiTesting_suppliedValue_isUsed() {
    XCTAssertEqual(
      resolve(isUITesting: true, ["SUPABASE_URL": "http://127.0.0.1:54321"]),
      .value("http://127.0.0.1:54321")
    )
  }

  func test_normalLaunch_isUntouchedWhetherOrNotTheValueIsSet() {
    XCTAssertEqual(resolve(isUITesting: false, [:]), .inactive)
    XCTAssertEqual(resolve(isUITesting: false, ["SUPABASE_URL": "http://127.0.0.1:54321"]), .inactive)
  }
}
