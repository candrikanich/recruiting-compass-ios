import XCTest
@testable import TheRecruitingCompass

/// Pins the wire contract for the family routes the app calls on the web API
/// (server/api/family/code/regenerate.post.ts, server/api/family/members/[memberId].delete.ts).
final class FamilyAPIClientTests: XCTestCase {
  private let baseURL = URL(string: "https://api.test.invalid")!

  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func makeClient(baseURL: URL? = URL(string: "https://api.test.invalid")) -> FamilyAPIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return FamilyAPIClient(session: URLSession(configuration: config), baseURL: baseURL, tokenProvider: { "tok-1" })
  }

  private func respond(_ status: Int, _ body: String, capture: @escaping @Sendable (URLRequest) -> Void = { _ in }) {
    StubURLProtocol.handler = { request in
      capture(request)
      let url = request.url!
      return (HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
    }
  }

  func test_regenerateCode_postsToApiRouteWithAuthAndClientHeaders() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    nonisolated(unsafe) var capturedBody: Data?
    respond(200, #"{"success":true,"familyCode":"FAM-NEW123"}"#) {
      captured = $0
      capturedBody = $0.httpBodyStream.flatMap { Self.read($0) } ?? $0.httpBody
    }

    let response = try await makeClient().regenerateCode(familyId: "fam-1")

    XCTAssertEqual(response.familyCode, "FAM-NEW123")
    XCTAssertEqual(captured?.httpMethod, "POST")
    XCTAssertEqual(captured?.url?.path, "/api/family/code/regenerate")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
    let json = try JSONSerialization.jsonObject(with: XCTUnwrap(capturedBody)) as? [String: String]
    XCTAssertEqual(json, ["familyId": "fam-1"])
  }

  func test_removeMember_sendsDeleteToMemberRoute() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    respond(200, #"{"success":true}"#) { captured = $0 }

    try await makeClient().removeMember(memberId: "mem-9")

    XCTAssertEqual(captured?.httpMethod, "DELETE")
    XCTAssertEqual(captured?.url?.path, "/api/family/members/mem-9")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
  }

  func test_removeMember_non2xx_surfacesServerMessage() async {
    respond(403, #"{"statusCode":403,"message":"Only the family owner can remove members"}"#)

    do {
      try await makeClient().removeMember(memberId: "mem-9")
      XCTFail("expected throw")
    } catch {
      XCTAssertEqual(error.localizedDescription, "Only the family owner can remove members")
    }
  }

  func test_regenerateCode_non2xxWithoutJsonMessage_usesGenericMessage() async {
    respond(502, "<html>bad gateway</html>")

    do {
      _ = try await makeClient().regenerateCode(familyId: "fam-1")
      XCTFail("expected throw")
    } catch {
      XCTAssertEqual(error.localizedDescription, "Something went wrong. Please try again.")
    }
  }

  func test_missingBaseURL_throwsConfigurationError() async {
    do {
      try await makeClient(baseURL: nil).removeMember(memberId: "mem-9")
      XCTFail("expected throw")
    } catch {
      XCTAssertEqual(error.localizedDescription, "App is not configured correctly. Please contact support.")
    }
  }

  func test_joinWithCode_postsFamilyCode() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    respond(200, #"{"success":true}"#) { captured = $0 }

    try await makeClient().joinFamily(familyCode: "FAM-ABC123")

    XCTAssertEqual(captured?.httpMethod, "POST")
    XCTAssertEqual(captured?.url?.path, "/api/family/code/join")
  }

  private static func read(_ stream: InputStream) -> Data {
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count <= 0 { break }
      data.append(buffer, count: count)
    }
    return data
  }
}
