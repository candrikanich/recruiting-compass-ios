import Supabase
import XCTest
@testable import TheRecruitingCompass

/// Pins the real queries (not the mock): prod RLS lets a multi-family user read every one of their
/// families' rows, so these client-side filters are what enforce "active family only" (#507).
@MainActor
final class ActivityFeedServiceImplQueryTests: XCTestCase {
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

  private func makeService() -> ActivityFeedServiceImpl {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let client = SupabaseClient(
      supabaseURL: URL(string: "https://example.supabase.co")!,
      supabaseKey: "anon-key",
      options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
    )
    return ActivityFeedServiceImpl(client: client)
  }

  private func query(_ request: URLRequest) -> [String: String] {
    let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
  }

  func testFetchInteractions_filtersByFamilyAndCapsAt200_neverByUser() async throws {
    _ = try await makeService().fetchInteractions(familyUnitId: "fam-A")

    let request = try XCTUnwrap(captured.requests.first)
    let params = query(request)
    XCTAssertEqual(request.url?.path, "/rest/v1/interactions")
    XCTAssertEqual(params["family_unit_id"], "eq.fam-A")
    XCTAssertEqual(params["limit"], "200")
    XCTAssertNil(params["logged_by"])
  }

  func testFetchDocuments_filtersByFamilyAndCapsAt200_neverByUser() async throws {
    _ = try await makeService().fetchDocuments(familyUnitId: "fam-A")

    let request = try XCTUnwrap(captured.requests.first)
    let params = query(request)
    XCTAssertEqual(request.url?.path, "/rest/v1/documents")
    XCTAssertEqual(params["family_unit_id"], "eq.fam-A")
    XCTAssertEqual(params["limit"], "200")
    XCTAssertNil(params["user_id"])
  }

  func testFetchStatusChanges_filtersThroughInnerJoinedSchoolsAndCapsAt200_neverByUser() async throws {
    _ = try await makeService().fetchStatusChanges(familyUnitId: "fam-A")

    let request = try XCTUnwrap(captured.requests.first)
    let params = query(request)
    XCTAssertEqual(request.url?.path, "/rest/v1/school_status_history")
    XCTAssertEqual(params["schools.family_unit_id"], "eq.fam-A")
    XCTAssertTrue(params["select"]?.contains("schools!inner(family_unit_id)") == true)
    XCTAssertEqual(params["limit"], "200")
    XCTAssertNil(params["changed_by"])
  }
}
