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

  // MARK: - load Tests

  func testLoadSetsLastUpdated() async {
    await sut.load()

    XCTAssertFalse(sut.lastUpdated.isEmpty)
    XCTAssertEqual(sut.lastUpdated, PrivacyPolicy.bundled.formattedDate)
  }

  func testLoadResetsLoadingToFalse() async {
    await sut.load()

    XCTAssertFalse(sut.isLoading)
  }

  func testLoadLoadsBundledContent() async {
    await sut.load()

    let bundled = PrivacyPolicy.bundled
    XCTAssertEqual(sut.lastUpdated, bundled.formattedDate)
  }

  func testLoadClearsError() async {
    sut.errorMessage = "Something failed"
    await sut.load()
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
