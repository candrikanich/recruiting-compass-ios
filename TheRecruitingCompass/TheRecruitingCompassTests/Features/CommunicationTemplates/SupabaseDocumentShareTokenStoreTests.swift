import Supabase
import XCTest
@testable import TheRecruitingCompass

/// Pins the real PostgREST requests (not the fake store): the `revoked_at is null` filter is what
/// stops iOS reusing a token the family revoked on web and sending coaches a dead link.
@MainActor
final class SupabaseDocumentShareTokenStoreTests: XCTestCase {
  nonisolated deinit {}

  private final class Captured: @unchecked Sendable {
    var requests: [URLRequest] = []
    var bodies: [Data] = []
  }

  private var captured = Captured()

  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func makeStore(status: Int = 200, body: String) -> SupabaseDocumentShareTokenStore {
    captured = Captured()
    let captured = captured
    StubURLProtocol.handler = { request in
      captured.requests.append(request)
      if let stream = request.httpBodyStream {
        captured.bodies.append(Self.read(stream))
      } else if let data = request.httpBody {
        captured.bodies.append(data)
      }
      let response = HTTPURLResponse(
        url: request.url!, statusCode: status, httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, Data(body.utf8))
    }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let client = SupabaseClient(
      supabaseURL: URL(string: "https://example.supabase.co")!,
      supabaseKey: "anon-key",
      options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
    )
    return SupabaseDocumentShareTokenStore(client: client)
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

  private func query(_ request: URLRequest) -> [String: String] {
    let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
  }

  func test_activeTokens_filtersByDocumentAndExcludesRevoked() async throws {
    let token = String(repeating: "a", count: 64)
    let store = makeStore(body: "[{\"token\":\"\(token)\"}]")

    let tokens = try await store.activeTokens(documentId: "doc-1")

    XCTAssertEqual(tokens, [token])
    let request = try XCTUnwrap(captured.requests.first)
    let params = query(request)
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url?.path, "/rest/v1/document_share_tokens")
    XCTAssertEqual(params["document_id"], "eq.doc-1")
    XCTAssertEqual(params["revoked_at"]?.lowercased(), "is.null")
  }

  func test_insertToken_sendsOnlyDocumentId() async throws {
    let token = String(repeating: "b", count: 64)
    let store = makeStore(status: 201, body: "{\"token\":\"\(token)\"}")

    let inserted = try await store.insertToken(documentId: "doc-1")

    XCTAssertEqual(inserted, token)
    let request = try XCTUnwrap(captured.requests.first)
    XCTAssertEqual(request.httpMethod, "POST")
    let body = try XCTUnwrap(captured.bodies.first)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
    XCTAssertEqual(json, ["document_id": "doc-1"])
  }

  func test_insertToken_uniqueViolationMapsToUniqueViolation() async {
    let store = makeStore(
      status: 409,
      body: "{\"code\":\"23505\",\"message\":\"duplicate key value\",\"details\":null,\"hint\":null}")
    do {
      _ = try await store.insertToken(documentId: "doc-1")
      XCTFail("expected throw")
    } catch DocumentShareTokenError.uniqueViolation {
      // expected
    } catch {
      XCTFail("wrong error: \(error)")
    }
  }
}
