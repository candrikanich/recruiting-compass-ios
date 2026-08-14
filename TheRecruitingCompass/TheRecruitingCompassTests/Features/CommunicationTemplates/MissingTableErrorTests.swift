import XCTest
@testable import TheRecruitingCompass

final class MissingTableErrorTests: XCTestCase {
  private struct StubError: LocalizedError {
    let msg: String
    var errorDescription: String? { msg }
  }

  func test_pgrst205IsMissingTable() {
    XCTAssertTrue(isMissingTableError(StubError(msg: "PGRST205: Could not find the table")))
  }

  func test_tableDoesNotExistIsMissingTable() {
    XCTAssertTrue(isMissingTableError(
      StubError(msg: "relation \"public.communication_templates\" does not exist")))
  }

  func test_unrelatedErrorIsNotMissingTable() {
    XCTAssertFalse(isMissingTableError(StubError(msg: "network timeout")))
  }
}
