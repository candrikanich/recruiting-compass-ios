import Helpers
import Supabase
import XCTest
@testable import TheRecruitingCompass

final class DatabaseErrorClassificationTests: XCTestCase {
  nonisolated deinit {}

  private func httpError(status: Int) -> HTTPError {
    let url = URL(string: "https://example.invalid/rest/v1/schools")!
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    return HTTPError(data: Data(), response: response)
  }

  func testIsPermissionDenied_postgrest42501_isTrue() {
    XCTAssertTrue(isPermissionDenied(PostgrestError(code: "42501", message: "rls")))
  }

  func testIsPermissionDenied_http403_isTrue() {
    XCTAssertTrue(isPermissionDenied(httpError(status: 403)))
  }

  func testIsPermissionDenied_http500_isFalse() {
    XCTAssertFalse(isPermissionDenied(httpError(status: 500)))
  }

  func testIsPermissionDenied_otherPostgrestCode_isFalse() {
    XCTAssertFalse(isPermissionDenied(PostgrestError(code: "22P02", message: "invalid uuid")))
  }

  func testIsPermissionDenied_plainError_isFalse() {
    XCTAssertFalse(isPermissionDenied(URLError(.notConnectedToInternet)))
  }
}
