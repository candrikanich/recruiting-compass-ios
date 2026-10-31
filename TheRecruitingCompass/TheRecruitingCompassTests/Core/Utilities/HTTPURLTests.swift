import XCTest
@testable import TheRecruitingCompass

final class HTTPURLTests: XCTestCase {
  func test_acceptsHttpAndHttpsInAnyCase() {
    for value in ["http://hudl.com/x", "https://youtu.be/x", "HTTPS://YouTu.be/x", "Http://vimeo.com/1"] {
      XCTAssertTrue(HTTPURL.isValid(value), value)
    }
  }

  func test_rejectsOtherSchemesAndSchemeLessInput() {
    let rejected = ["javascript:alert(1)", "data:text/html,hi", "file:///etc/passwd", "ftp://host/x",
                    "hudl.com/x", "www.youtube.com/watch", "", " https://hudl.com/x", "httpx://hudl.com"]
    for value in rejected {
      XCTAssertFalse(HTTPURL.isValid(value), value)
      XCTAssertNil(HTTPURL.url(from: value), value)
    }
  }

  func test_urlFromReturnsParsedHttpURL() {
    XCTAssertEqual(HTTPURL.url(from: "https://hudl.com/x")?.host, "hudl.com")
  }
}
