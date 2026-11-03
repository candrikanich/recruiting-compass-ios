import Supabase
import XCTest
@testable import TheRecruitingCompass

/// Pins the real PostgREST queries (not the mock). #228's headline bug was an unordered `.limit(1)` that made
/// a multi-family parent land in an arbitrary family; the order and the player filter are what fix it.
@MainActor
final class FamilyServiceImplQueryTests: XCTestCase {
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

  private func makeService() -> FamilyServiceImpl {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let client = SupabaseClient(
      supabaseURL: URL(string: "https://example.supabase.co")!,
      supabaseKey: "anon-key",
      options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
    )
    return FamilyServiceImpl(supabaseManager: .shared, client: client)
  }

  private func query(_ request: URLRequest) -> [String: String] {
    let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
  }

  func testGetMemberships_listsEveryFamilyNewestFirst_neverLimitedToOne() async throws {
    _ = try await makeService().getMemberships(userId: "parent-1")

    let request = try XCTUnwrap(captured.requests.first)
    let params = query(request)
    XCTAssertEqual(request.url?.path, "/rest/v1/family_members")
    XCTAssertEqual(params["user_id"], "eq.parent-1")
    XCTAssertEqual(params["order"], "added_at.desc.nullslast")
    XCTAssertNil(params["limit"])
  }

  func testFamilyPlayers_asksForPlayersOfTheGivenFamiliesWithTheirGraduationYear() async throws {
    _ = try await makeService().familyPlayers(among: ["fam-A", "fam-B"])

    let request = try XCTUnwrap(captured.requests.first)
    let params = query(request)
    XCTAssertEqual(request.url?.path, "/rest/v1/family_members")
    XCTAssertEqual(params["role"], "eq.player")
    XCTAssertEqual(params["family_unit_id"], "in.(fam-A,fam-B)")
    XCTAssertTrue(params["select"]?.contains("graduation_year") == true)
  }

  func testGetFamilyUnitForUser_usesTheNewestMembership() async throws {
    _ = try await makeService().getFamilyUnit(forUserId: "parent-1")

    let first = try XCTUnwrap(captured.requests.first)
    XCTAssertEqual(query(first)["order"], "added_at.desc.nullslast")
  }
}
