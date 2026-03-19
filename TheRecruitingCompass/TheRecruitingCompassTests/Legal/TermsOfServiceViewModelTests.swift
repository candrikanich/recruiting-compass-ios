import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TermsOfServiceViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: TermsOfServiceViewModel!

  override func setUp() {
    super.setUp()
    sut = TermsOfServiceViewModel()
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func testLastUpdatedReturnsBundledFormattedDate() {
    XCTAssertFalse(sut.lastUpdated.isEmpty)
    XCTAssertEqual(sut.lastUpdated, TermsOfService.bundled.formattedDate)
  }
}
