import XCTest
@testable import TheRecruitingCompass

final class CrashReportingTests: XCTestCase {
  func test_missingKeyDisablesReporting() {
    XCTAssertNil(CrashReporting.dsn(from: [:]))
    XCTAssertNil(CrashReporting.dsn(from: nil))
  }

  func test_emptyOrUnexpandedValueDisablesReporting() {
    XCTAssertNil(CrashReporting.dsn(from: ["SentryDSN": ""]))
    XCTAssertNil(CrashReporting.dsn(from: ["SentryDSN": "  "]))
    XCTAssertNil(CrashReporting.dsn(from: ["SentryDSN": "$(SENTRY_DSN)"]))
  }

  func test_configuredDSNIsReturnedTrimmed() {
    let dsn = "https://abc123@o1.ingest.us.sentry.io/42"
    XCTAssertEqual(CrashReporting.dsn(from: ["SentryDSN": " \(dsn) "]), dsn)
  }

  func test_debugBuildInfoPlistHasNoDSN() {
    // Debug builds use Config/Info.plist, which must never carry a DSN.
    XCTAssertNil(CrashReporting.dsn(from: Bundle.main.infoDictionary))
  }
}
