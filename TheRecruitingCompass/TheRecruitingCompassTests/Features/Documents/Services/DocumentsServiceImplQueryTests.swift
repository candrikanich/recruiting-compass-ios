import Supabase
import XCTest
@testable import TheRecruitingCompass

/// Pins the real list query (not the mock): the family filter is what lets a document another member
/// uploaded show up, and what keeps another family's out (#573).
@MainActor
final class DocumentsServiceImplQueryTests: XCTestCase {
  nonisolated deinit {}

  private final class Captured: @unchecked Sendable {
    var requests: [URLRequest] = []
  }

  private var captured = Captured()

  override func setUp() {
    super.setUp()
    captured = Captured()
    let captured = captured
    StubURLProtocol.handler = { request in
      captured.requests.append(request)
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, Data("[]".utf8))
    }
  }

  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func makeService() -> DocumentsServiceImpl {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let client = SupabaseClient(
      supabaseURL: URL(string: "https://example.supabase.co")!,
      supabaseKey: "anon-key",
      options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
    )
    return DocumentsServiceImpl(client: client)
  }

  private func query(_ request: URLRequest) -> [String: String] {
    let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
  }

  func testFetchDocuments_filtersByFamily_neverByUploader() async throws {
    _ = try await makeService().fetchDocuments(familyUnitId: "fam-A")

    let request = try XCTUnwrap(captured.requests.first)
    let params = query(request)
    XCTAssertEqual(request.url?.path, "/rest/v1/documents")
    XCTAssertEqual(params["family_unit_id"], "eq.fam-A")
    XCTAssertNil(params["user_id"])
  }
}
