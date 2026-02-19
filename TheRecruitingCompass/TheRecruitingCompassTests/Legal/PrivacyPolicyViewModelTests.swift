import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PrivacyPolicyViewModelTests: XCTestCase {
  var sut: PrivacyPolicyViewModel!

  override func setUp() {
    super.setUp()
    sut = PrivacyPolicyViewModel()
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  // MARK: - Initial State Tests

  func testInitialState() {
    XCTAssertEqual(sut.lastUpdated, "")
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - loadPolicy Tests

  func testLoadPolicySetsLastUpdated() async {
    await sut.loadPolicy()

    XCTAssertFalse(sut.lastUpdated.isEmpty)
    XCTAssertEqual(sut.lastUpdated, PrivacyPolicy.bundled.formattedDate)
  }

  func testLoadPolicyResetsLoadingToFalse() async {
    await sut.loadPolicy()

    XCTAssertFalse(sut.isLoading)
  }

  func testLoadPolicyLoadsBundledContent() async {
    await sut.loadPolicy()

    let bundled = PrivacyPolicy.bundled
    XCTAssertEqual(sut.lastUpdated, bundled.formattedDate)
  }

  func testLoadPolicyClearsError() async {
    sut.errorMessage = "Something failed"
    await sut.loadPolicy()
    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - retry Tests

  func testRetryClearsErrorAndReloads() async {
    sut.errorMessage = "Network error"
    await sut.retry()
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(sut.lastUpdated, PrivacyPolicy.bundled.formattedDate)
  }
}
