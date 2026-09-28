import XCTest
@testable import TheRecruitingCompass

final class AppVersionTests: XCTestCase {
  private func v(_ string: String) -> AppVersion {
    guard let version = AppVersion(string) else {
      XCTFail("Expected \(string) to parse")
      return AppVersion(major: 0, minor: 0, patch: 0)
    }
    return version
  }

  // MARK: - Parsing

  func test_parsesOneTwoAndThreeComponents() {
    XCTAssertEqual(AppVersion("2"), AppVersion(major: 2, minor: 0, patch: 0))
    XCTAssertEqual(AppVersion("1.4"), AppVersion(major: 1, minor: 4, patch: 0))
    XCTAssertEqual(AppVersion("1.4.7"), AppVersion(major: 1, minor: 4, patch: 7))
  }

  func test_trimsWhitespace() {
    XCTAssertEqual(AppVersion(" 1.0.1\n"), AppVersion(major: 1, minor: 0, patch: 1))
  }

  func test_rejectsMalformedStrings() {
    for bad in ["", "1.", ".1", "1..0", "1.0.0.0", "v1.0", "1.0-beta", "-1.0", "abc"] {
      XCTAssertNil(AppVersion(bad), "\(bad) should not parse")
    }
  }

  func test_descriptionIsNormalizedToThreeParts() {
    XCTAssertEqual(v("1.0").description, "1.0.0")
  }

  // MARK: - Ordering

  func test_comparesNumericallyNotLexically() {
    XCTAssertLessThan(v("1.9"), v("1.10"))
    XCTAssertLessThan(v("1.0.9"), v("1.1"))
    XCTAssertLessThan(v("1.99.99"), v("2"))
  }

  func test_missingComponentsEqualZero() {
    XCTAssertEqual(v("1"), v("1.0.0"))
    XCTAssertFalse(v("1.0") < v("1.0.0"))
  }

  // MARK: - Update status

  private func status(current: String, minimum: String?, recommended: String?) -> AppUpdateStatus {
    AppUpdateStatus.evaluate(
      current: v(current),
      policy: AppVersionPolicy(minimumVersion: minimum, recommendedVersion: recommended)
    )
  }

  func test_noPolicyIsUpToDate() {
    XCTAssertEqual(status(current: "1.0", minimum: nil, recommended: nil), .upToDate)
  }

  func test_belowMinimumRequiresUpdate() {
    XCTAssertEqual(status(current: "1.0", minimum: "1.0.1", recommended: nil), .updateRequired(v("1.0.1")))
  }

  func test_atMinimumIsNotRequired() {
    XCTAssertEqual(status(current: "1.0.1", minimum: "1.0.1", recommended: nil), .upToDate)
  }

  func test_belowRecommendedButAboveMinimumIsAvailable() {
    XCTAssertEqual(
      status(current: "1.1", minimum: "1.0", recommended: "1.2"),
      .updateAvailable(v("1.2"))
    )
  }

  func test_requiredWinsOverAvailable() {
    XCTAssertEqual(
      status(current: "1.0", minimum: "1.1", recommended: "1.2"),
      .updateRequired(v("1.1"))
    )
  }

  func test_currentAheadOfPolicyIsUpToDate() {
    // TestFlight builds run ahead of what the policy knows about.
    XCTAssertEqual(status(current: "1.3", minimum: "1.1", recommended: "1.2"), .upToDate)
  }

  func test_unparseablePolicyValuesAreIgnored() {
    // A typo in the config row must never lock everyone out.
    XCTAssertEqual(status(current: "1.0", minimum: "one.two", recommended: "latest"), .upToDate)
  }
}
