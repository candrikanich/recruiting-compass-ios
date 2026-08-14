import XCTest
@testable import TheRecruitingCompass

/// Reuses the `StubURLProtocol` + CSRF-cookie seeding pattern from PublicProfileServiceImplTests.
final class AthleteMessagesServiceTests: XCTestCase {
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

  func test_checkSend_decodesResult() async throws {
    seedCSRFCookie()
    StubURLProtocol.handler = { request in
      if request.url!.path.hasSuffix("/csrf-token") {
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{}".utf8))
      }
      XCTAssertEqual(request.value(forHTTPHeaderField: "x-csrf-token"), "test-csrf")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
      let body = Data(#"{"programNoteReused":true,"daysSinceLastContact":3,"recentContact":true,"messageCountToSchool":2}"#.utf8)
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
    }
    let svc = AthleteMessagesServiceImpl(
      session: makeSession(), baseURLOverride: URL(string: "https://test.local")!)
    let res = try await svc.checkSend(
      .init(athleteUserId: "a1", schoolId: "s1", programNote: "note"), accessToken: "tok")
    XCTAssertTrue(res.programNoteReused)
    XCTAssertEqual(res.messageCountToSchool, 2)
    XCTAssertEqual(res.daysSinceLastContact, 3)
  }

  func test_logSend_succeedsOn200() async throws {
    seedCSRFCookie()
    StubURLProtocol.handler = { request in
      if request.url!.path.hasSuffix("/csrf-token") {
        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{}".utf8))
      }
      return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
              Data(#"{"success":true,"id":"m1"}"#.utf8))
    }
    let svc = AthleteMessagesServiceImpl(
      session: makeSession(), baseURLOverride: URL(string: "https://test.local")!)
    try await svc.logSend(.init(athleteUserId: "a1", schoolId: "s1", coachId: "c1",
      templateSlug: "intro", channel: "email", programNote: "n", updateHook: nil,
      subject: "s", body: "b"), accessToken: "tok")
  }

  func test_missingToken_throwsNotConfigured() async {
    let svc = AthleteMessagesServiceImpl(
      session: makeSession(), baseURLOverride: URL(string: "https://test.local")!)
    do {
      _ = try await svc.checkSend(.init(athleteUserId: "a1", schoolId: nil, programNote: nil),
                                  accessToken: nil)
      XCTFail("expected throw")
    } catch AthleteMessagesError.notConfigured { /* ok */ }
    catch { XCTFail("wrong error: \(error)") }
  }
}
