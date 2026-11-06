import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DeepLinkHandlerTests: XCTestCase {
  nonisolated deinit {}

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

  func testJoinUniversalLinkParsesToJoinInvite() {
    let url = URL(string: "https://myrecruitingcompass.com/join?token=abc123")!
    XCTAssertEqual(DeepLinkHandler.parse(url), .joinInvite(token: "abc123"))
  }

  func testGuardianClaimUniversalLink() {
    let url = URL(string: "https://myrecruitingcompass.com/guardian/claim/abc123")!
    XCTAssertEqual(DeepLinkHandler.parse(url), .guardianClaim(token: "abc123"))
  }

  func testLegacyInvitePathIsUnknown() {
    let url = URL(string: "https://myrecruitingcompass.com/invite/abc123")!
    XCTAssertEqual(DeepLinkHandler.parse(url), .unknown)
  }
}
