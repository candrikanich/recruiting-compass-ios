import XCTest
@testable import TheRecruitingCompass

/// Pins how change-password / change-email 429 and 401 responses surface (ios#591): a rate limit is not a
/// generic failure, and only the server's `incorrect_password` code means the typed password was wrong.
final class ProfileServiceAuthChangeErrorsTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func service(status: Int, body: String) -> ProfileServiceImpl {
    StubURLProtocol.handler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
    }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return ProfileServiceImpl(
      session: URLSession(configuration: config),
      baseURL: URL(string: "https://api.test.invalid"),
      tokenProvider: { "tok-1" }
    )
  }

  private static let rateLimitedBody = #"{"statusCode":429,"data":{"retryAfter":3600}}"#
  private static let rateLimitedBodyOverADay = #"{"statusCode":429,"data":{"retryAfter":86400}}"#
  private static let wrongPasswordBody = #"{"statusCode":401,"data":{"code":"incorrect_password"}}"#
  private static let invalidTokenBody = #"{"statusCode":401,"statusMessage":"Invalid token"}"#
  private static let otherCodeBody = #"{"statusCode":401,"data":{"code":"something_else"}}"#

  private enum Call: CaseIterable {
    case changePassword, changeEmail

    func run(_ service: ProfileServiceImpl) async throws {
      switch self {
      case .changePassword: try await service.changePassword(currentPassword: "pw", newPassword: "new-pw-123")
      case .changeEmail: try await service.changeEmail(newEmail: "new@example.com", currentPassword: "pw")
      }
    }
  }

  private func assertError(
    _ expected: String, status: Int, body: String, call: Call, line: UInt = #line
  ) async {
    do {
      try await call.run(service(status: status, body: body))
      XCTFail("expected throw (\(call))", line: line)
    } catch let error as ProfileServiceError {
      XCTAssertEqual(error.errorDescription, expected, "\(call)", line: line)
    } catch {
      XCTFail("wrong error \(error)", line: line)
    }
  }

  func test_429_showsTooManyAttempts() async {
    for call in Call.allCases {
      await assertError("Too many attempts. Try again later.", status: 429, body: Self.rateLimitedBody, call: call)
    }
  }

  func test_429_neverShowsDataExportText() async {
    for call in Call.allCases {
      await assertError(
        "Too many attempts. Try again later.", status: 429, body: Self.rateLimitedBodyOverADay, call: call)
    }
  }

  func test_429_withoutBody_stillShowsTooManyAttempts() async {
    for call in Call.allCases {
      await assertError("Too many attempts. Try again later.", status: 429, body: "", call: call)
    }
  }

  func test_401WithIncorrectPasswordCode_showsWrongPassword() async {
    for call in Call.allCases {
      await assertError("Current password is incorrect.", status: 401, body: Self.wrongPasswordBody, call: call)
    }
  }

  func test_401WithoutCode_showsSessionExpired() async {
    for call in Call.allCases {
      await assertError(
        "Your session has expired. Please sign in again.", status: 401, body: Self.invalidTokenBody, call: call)
    }
  }

  func test_401WithOtherCode_showsSessionExpired() async {
    for call in Call.allCases {
      await assertError(
        "Your session has expired. Please sign in again.", status: 401, body: Self.otherCodeBody, call: call)
    }
  }

  func test_401WithEmptyBody_showsSessionExpired() async {
    for call in Call.allCases {
      await assertError("Your session has expired. Please sign in again.", status: 401, body: "", call: call)
    }
  }

  func test_otherNon2xx_keepsGenericFailure() async {
    for call in Call.allCases {
      await assertError("Request failed. Please try again.", status: 500, body: "{}", call: call)
    }
  }
}
