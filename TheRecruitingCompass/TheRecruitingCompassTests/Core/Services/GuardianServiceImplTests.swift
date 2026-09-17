import XCTest
@testable import TheRecruitingCompass

/// Reuses the `StubURLProtocol` pattern from PublicProfileServiceImplTests/AthleteMessagesServiceTests.
final class GuardianServiceImplTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    HTTPCookieStorage.shared.cookies?
      .filter { $0.name == "csrf-token" }
      .forEach { HTTPCookieStorage.shared.deleteCookie($0) }
    super.tearDown()
  }

  private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
  }

  private func seedCSRFCookie() {
    let cookie = HTTPCookie(properties: [
      .domain: "test.local", .path: "/", .name: "csrf-token", .value: "test-csrf"])!
    HTTPCookieStorage.shared.setCookie(cookie)
  }

  /// A guardian-free signup's real wire response (server/api/auth/signup-minor.post.ts's
  /// `{ ok: true, guardianEmail: null, guardianEmailSent: false, tokenHash }` shape) must
  /// decode successfully, not throw — `SignupMinorResult.guardianEmail` is optional for
  /// exactly this reason.
  func test_signupMinor_decodesGuardianFreeResponse() async throws {
    seedCSRFCookie()
    StubURLProtocol.handler = { request in
      if request.url!.path.hasSuffix("/csrf-token") {
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{}".utf8))
      }
      let body = Data(#"{"ok":true,"guardianEmail":null,"guardianEmailSent":false,"tokenHash":"hash-1"}"#.utf8)
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
    }
    let svc = GuardianServiceImpl(
      session: makeSession(), baseURLOverride: URL(string: "https://test.local")!)

    let result = try await svc.signupMinor(
      email: "player@example.com", password: "StrongPass123", firstName: "Owen", lastName: "Smith",
      dateOfBirth: "2011-01-01", guardianEmail: nil, captchaToken: "tok",
      graduationYear: nil, primarySport: nil, gender: nil, zipCode: nil)

    XCTAssertTrue(result.ok)
    XCTAssertNil(result.guardianEmail)
    XCTAssertFalse(result.guardianEmailSent)
  }

  func test_signupMinor_decodesGuardianProvidedResponse() async throws {
    seedCSRFCookie()
    StubURLProtocol.handler = { request in
      if request.url!.path.hasSuffix("/csrf-token") {
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{}".utf8))
      }
      let body = Data(#"{"ok":true,"guardianEmail":"parent@example.com","guardianEmailSent":true}"#.utf8)
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
    }
    let svc = GuardianServiceImpl(
      session: makeSession(), baseURLOverride: URL(string: "https://test.local")!)

    let result = try await svc.signupMinor(
      email: "player@example.com", password: "StrongPass123", firstName: "Owen", lastName: "Smith",
      dateOfBirth: "2011-01-01", guardianEmail: "parent@example.com", captchaToken: "tok",
      graduationYear: nil, primarySport: nil, gender: nil, zipCode: nil)

    XCTAssertEqual(result.guardianEmail, "parent@example.com")
    XCTAssertTrue(result.guardianEmailSent)
  }
}
