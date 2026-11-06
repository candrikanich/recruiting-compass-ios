import XCTest
@testable import TheRecruitingCompass

/// A resend is revoke + create; the create must land in the invitation's family, not the sender's fallback.
@MainActor
final class FamilyServiceImplResendTests: XCTestCase {
  nonisolated deinit {}

  private struct Call {
    let method: String
    let path: String
    let body: [String: Any]?
  }

  private final class Captured: @unchecked Sendable {
    var requests: [Call] = []
  }

  private func makeService(captured: Captured) -> FamilyServiceImpl {
    StubURLProtocol.handler = { request in
      let body = request.httpBody ?? request.httpBodyStream.flatMap { stream -> Data in
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
          let read = stream.read(&buffer, maxLength: buffer.count)
          if read <= 0 { break }
          data.append(buffer, count: read)
        }
        return data
      }
      captured.requests.append(Call(
        method: request.httpMethod ?? "",
        path: request.url?.path ?? "",
        body: body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
      ))
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data("{}".utf8))
    }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return FamilyServiceImpl(
      supabaseManager: .shared,
      apiSession: URLSession(configuration: config),
      apiBaseURL: URL(string: "https://api.example.test"),
      accessToken: { "token" }
    )
  }

  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  func testResendInvitation_recreatesTheInviteInTheGivenFamily() async throws {
    let captured = Captured()

    try await makeService(captured: captured).resendInvitation(
      id: "i1", email: "gran@example.com", role: "parent", familyUnitId: "family-A"
    )

    XCTAssertEqual(captured.requests.map(\.method), ["DELETE", "POST"])
    XCTAssertEqual(captured.requests.last?.path, "/api/family/invite")
    XCTAssertEqual(captured.requests.last?.body?["family_unit_id"] as? String, "family-A")
  }
}
