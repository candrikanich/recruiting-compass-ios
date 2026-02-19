import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TermsOfServiceViewModelTests: XCTestCase {
  var sut: TermsOfServiceViewModel!

  override func setUp() {
    super.setUp()
    sut = TermsOfServiceViewModel()
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

  // MARK: - loadTerms Tests

  func testLoadTermsSetsLastUpdated() async {
    await sut.loadTerms()

    XCTAssertFalse(sut.lastUpdated.isEmpty)
    XCTAssertEqual(sut.lastUpdated, TermsOfService.bundled.formattedDate)
  }

  func testLoadTermsResetsLoadingToFalse() async {
    await sut.loadTerms()

    XCTAssertFalse(sut.isLoading)
  }

  func testLoadTermsLoadsBundledContent() async {
    await sut.loadTerms()

    let bundled = TermsOfService.bundled
    XCTAssertEqual(sut.lastUpdated, bundled.formattedDate)
  }

  func testLoadTermsClearsError() async {
    sut.errorMessage = "Something failed"
    await sut.loadTerms()
    XCTAssertNil(sut.errorMessage)
  }

  // MARK: - retry Tests

  func testRetryClearsErrorAndReloads() async {
    sut.errorMessage = "Network error"
    await sut.retry()
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(sut.lastUpdated, TermsOfService.bundled.formattedDate)
  }
}
