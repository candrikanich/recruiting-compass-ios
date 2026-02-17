import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DeepLinkHandlerTests: XCTestCase {

  func testValidResetPasswordURL() {
    let url = URL(string: "recruiting-compass://reset-password?token=abc123")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .resetPassword(token: "abc123"))
  }

  func testMissingToken() {
    let url = URL(string: "recruiting-compass://reset-password")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .unknown)
  }

  func testEmptyToken() {
    let url = URL(string: "recruiting-compass://reset-password?token=")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .unknown)
  }

  func testWrongScheme() {
    let url = URL(string: "https://reset-password?token=abc123")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .unknown)
  }

  func testWrongHost() {
    let url = URL(string: "recruiting-compass://verify-email?token=abc123")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .unknown)
  }

  func testTokenWithSpecialCharacters() {
    let url = URL(string: "recruiting-compass://reset-password?token=abc-123_def.456")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .resetPassword(token: "abc-123_def.456"))
  }

  func testMultipleQueryParams() {
    let url = URL(string: "recruiting-compass://reset-password?token=abc123&extra=value")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .resetPassword(token: "abc123"))
  }

  func testTokenOnlyNoQueryParamName() {
    let url = URL(string: "recruiting-compass://reset-password?abc123")!
    let route = DeepLinkHandler.parse(url)
    XCTAssertEqual(route, .unknown)
  }
}
