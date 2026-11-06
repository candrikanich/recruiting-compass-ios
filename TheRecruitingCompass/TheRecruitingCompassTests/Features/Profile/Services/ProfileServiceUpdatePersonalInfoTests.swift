import XCTest
@testable import TheRecruitingCompass

/// Wires PATCH /api/user/profile failures through the real request path (ios#395).
final class ProfileServiceUpdatePersonalInfoTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func service(responding status: Int, _ body: String) -> ProfileServiceImpl {
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

  func test_400FieldError_throwsServerDateOfBirthMessage() async {
    let body = #"{"statusMessage":"Invalid profile data","data":{"fieldErrors":{"date_of_birth":["Too young."]}}}"#
    await assertDateOfBirthError(status: 400, body: body, message: "Too young.")
  }

  func test_403LockedForMinor_throwsServerDateOfBirthMessage() async {
    let body = #"{"statusMessage":"Locked until a guardian confirms.","data":{"code":"date_of_birth_locked_for_minor"}}"#
    await assertDateOfBirthError(status: 403, body: body, message: "Locked until a guardian confirms.")
  }

  func test_otherFailure_keepsGenericServerError() async {
    do {
      try await service(responding: 500, #"{"statusMessage":"boom"}"#)
        .updatePersonalInfo(fullName: "A", dateOfBirth: nil)
      XCTFail("expected throw")
    } catch ProfileServiceError.serverError(let message) {
      XCTAssertEqual(message, "Request failed. Please try again.")
    } catch {
      XCTFail("wrong error \(error)")
    }
  }

  private func assertDateOfBirthError(status: Int, body: String, message: String, line: UInt = #line) async {
    do {
      try await service(responding: status, body).updatePersonalInfo(fullName: "A", dateOfBirth: "2012-01-01")
      XCTFail("expected throw", line: line)
    } catch ProfileServiceError.dateOfBirth(let text) {
      XCTAssertEqual(text, message, line: line)
    } catch {
      XCTFail("wrong error \(error)", line: line)
    }
  }
}
