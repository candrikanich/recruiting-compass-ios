import XCTest
@testable import TheRecruitingCompass

/// Pins how POST /api/auth/change-email failures surface (ios#498): same-address 400, rate limit 429,
/// unsent security notice 502 all map to the generic failure message.
final class ProfileServiceChangeEmailTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func service(responding status: Int) -> ProfileServiceImpl {
    StubURLProtocol.handler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
    }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return ProfileServiceImpl(
      session: URLSession(configuration: config),
      baseURL: URL(string: "https://api.test.invalid"),
      tokenProvider: { "tok-1" }
    )
  }

  func test_400SameAddress_showsGenericFailure() async { await assertGenericFailure(status: 400) }
  func test_429RateLimited_showsGenericFailure() async { await assertGenericFailure(status: 429) }
  func test_502NoticeNotSent_showsGenericFailure() async { await assertGenericFailure(status: 502) }

  func test_200_succeeds() async throws {
    try await service(responding: 200).changeEmail(newEmail: "new@example.com", currentPassword: "pw")
  }

  private func assertGenericFailure(status: Int, line: UInt = #line) async {
    do {
      try await service(responding: status).changeEmail(newEmail: "new@example.com", currentPassword: "pw")
      XCTFail("expected throw", line: line)
    } catch ProfileServiceError.serverError(let message) {
      XCTAssertEqual(message, "Request failed. Please try again.", line: line)
    } catch {
      XCTFail("wrong error \(error)", line: line)
    }
  }
}
