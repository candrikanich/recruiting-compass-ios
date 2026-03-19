import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PrivacyPolicyViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: PrivacyPolicyViewModel!

  override func setUp() {
    super.setUp()
    sut = PrivacyPolicyViewModel()
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func testLastUpdatedReturnsBundledFormattedDate() {
    XCTAssertFalse(sut.lastUpdated.isEmpty)
    XCTAssertEqual(sut.lastUpdated, PrivacyPolicy.bundled.formattedDate)
  }
}
