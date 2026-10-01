import XCTest
@testable import TheRecruitingCompass

final class MarketingConsentServiceImplTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func makeService(token: String? = "tok") -> MarketingConsentServiceImpl {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return MarketingConsentServiceImpl(
      session: URLSession(configuration: config),
      baseURLOverride: URL(string: "https://test.local")!,
      accessTokenProvider: { token }
    )
  }

  private static func respond(_ request: URLRequest, status: Int, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(body.utf8))
  }

  /// URLProtocol receives POST/PATCH bodies as a stream, not `httpBody`.
  private static func bodyData(of request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
      let read = stream.read(&buffer, maxLength: buffer.count)
      guard read > 0 else { break }
      data.append(buffer, count: read)
    }
    return data
  }

  func test_fetch_sendsAuthorizedGetWithClientHeaders() async throws {
    StubURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/api/user/marketing-consent")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
      XCTAssertEqual(request.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
      return Self.respond(
        request, status: 200, body: #"{"eligible":true,"optIn":true,"updatedAt":"2026-10-01T00:00:00Z"}"#
      )
    }
    let consent = try await makeService().fetchConsent()
    XCTAssertEqual(consent, MarketingConsent(eligible: true, optIn: true, updatedAt: "2026-10-01T00:00:00Z"))
  }

  func test_fetch_decodesNullUpdatedAt() async throws {
    StubURLProtocol.handler = { request in
      Self.respond(request, status: 200, body: #"{"eligible":false,"optIn":false,"updatedAt":null}"#)
    }
    let consent = try await makeService().fetchConsent()
    XCTAssertFalse(consent.eligible)
    XCTAssertNil(consent.updatedAt)
  }

  func test_update_sendsPatchBody() async throws {
    StubURLProtocol.handler = { request in
      XCTAssertEqual(request.httpMethod, "PATCH")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      XCTAssertEqual(request.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
      let body = Self.bodyData(of: request).flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
      }
      XCTAssertEqual(body?["optIn"] as? Bool, true)
      return Self.respond(request, status: 200, body: #"{"eligible":true,"optIn":true,"updatedAt":null}"#)
    }
    let consent = try await makeService().updateConsent(optIn: true)
    XCTAssertTrue(consent.optIn)
  }

  func test_update_403_throwsNotEligible() async {
    StubURLProtocol.handler = { request in Self.respond(request, status: 403, body: "{}") }
    do {
      _ = try await makeService().updateConsent(optIn: true)
      XCTFail("expected throw")
    } catch MarketingConsentError.notEligible {
    } catch { XCTFail("wrong error: \(error)") }
  }

  func test_fetch_401_throwsUnauthenticated() async {
    StubURLProtocol.handler = { request in Self.respond(request, status: 401, body: "{}") }
    do {
      _ = try await makeService().fetchConsent()
      XCTFail("expected throw")
    } catch MarketingConsentError.unauthenticated {
    } catch { XCTFail("wrong error: \(error)") }
  }

  func test_missingToken_throwsUnauthenticated() async {
    do {
      _ = try await makeService(token: nil).fetchConsent()
      XCTFail("expected throw")
    } catch MarketingConsentError.unauthenticated {
    } catch { XCTFail("wrong error: \(error)") }
  }
}
