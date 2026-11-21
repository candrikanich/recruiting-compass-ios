import Supabase
import XCTest
@testable import TheRecruitingCompass

/// Pins the real first-run queries: the status score must stay hidden for a family with a coach but no logged
/// conversation, so each count has to hit its own table, scoped to the family, and land in its own field (#629).
@MainActor
final class DashboardServiceFirstRunSignalsTests: XCTestCase {
  nonisolated deinit {}

  private final class Captured: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []
    func record(_ request: URLRequest) { lock.withLock { stored.append(request) } }
    var requests: [URLRequest] { lock.withLock { stored } }

    private var ranges: [String: String] = [:]
    func setRanges(_ new: [String: String]) { lock.withLock { ranges = new } }
    func range(for table: String) -> String { lock.withLock { ranges[table] ?? "*/0" } }
  }

  private var captured = Captured()
  private var countsByTable: [String: String] {
    get { [:] }
    set { captured.setRanges(newValue) }
  }

  override func setUp() {
    super.setUp()
    captured = Captured()
    let captured = captured
    StubURLProtocol.handler = { request in
      captured.record(request)
      let table = request.url?.lastPathComponent ?? ""
      let range = captured.range(for: table)
      let isSchools = table == "schools"
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil,
        headerFields: ["Content-Type": "application/json", "Content-Range": range]
      )!
      return (response, Data(isSchools ? #"[{"name":"Duke"}]"#.utf8 : "[]".utf8))
    }
  }

  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func makeService() -> DashboardServiceImpl {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let client = SupabaseClient(
      supabaseURL: URL(string: "https://example.supabase.co")!,
      supabaseKey: "anon-key",
      options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
    )
    return DashboardServiceImpl(supabaseManager: SupabaseManager(client: client))
  }

  private func params(_ request: URLRequest) -> [String: String] {
    let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
  }

  private func requests(forTable table: String) -> [URLRequest] {
    captured.requests.filter { $0.url?.path == "/rest/v1/\(table)" }
  }

  func testFetchFirstRunSignals_countsCoachesAndInteractionsEachScopedToTheFamily() async throws {
    _ = try await makeService().fetchFirstRunSignals(familyUnitId: "fam-A")

    for table in ["coaches", "interactions"] {
      let matching = requests(forTable: table)
      XCTAssertEqual(matching.count, 1, "\(table) must be queried exactly once")
      let request = try XCTUnwrap(matching.first)
      XCTAssertEqual(request.httpMethod, "HEAD", "\(table) is a count-only request")
      XCTAssertEqual(params(request)["family_unit_id"], "eq.fam-A", "\(table) must be scoped to the family")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "count=exact")
    }
  }

  func testFetchFirstRunSignals_mapsEachCountToItsOwnField() async throws {
    countsByTable = ["coaches": "0-0/3", "interactions": "*/0"]
    let coachOnly = try await makeService().fetchFirstRunSignals(familyUnitId: "fam-A")
    XCTAssertEqual(coachOnly.coachCount, 3)
    XCTAssertEqual(coachOnly.conversationCount, 0)
    XCTAssertFalse(coachOnly.isStatusScoreVisible, "a coach with no logged conversation must not show the score")

    countsByTable = ["coaches": "*/0", "interactions": "0-0/5"]
    let conversationOnly = try await makeService().fetchFirstRunSignals(familyUnitId: "fam-A")
    XCTAssertEqual(conversationOnly.coachCount, 0)
    XCTAssertEqual(conversationOnly.conversationCount, 5)
  }

  func testFetchFirstRunSignals_readsFavoriteSchoolScopedToTheFamily() async throws {
    let signals = try await makeService().fetchFirstRunSignals(familyUnitId: "fam-A")

    XCTAssertEqual(signals.favoriteSchoolName, "Duke")
    let request = try XCTUnwrap(requests(forTable: "schools").first)
    XCTAssertEqual(params(request)["family_unit_id"], "eq.fam-A")
    XCTAssertEqual(params(request)["is_favorite"], "eq.true")
  }

  func testExactCount_returnsTheTotalFromTheContentRangeHeader() async throws {
    countsByTable = ["coaches": "0-0/7"]
    let count = try await makeService().exactCount(table: "coaches", column: "family_unit_id", value: "fam-B")

    XCTAssertEqual(count, 7)
    let request = try XCTUnwrap(requests(forTable: "coaches").first)
    XCTAssertEqual(params(request)["family_unit_id"], "eq.fam-B")
  }

  func testExactCount_isZeroWhenTheTableIsEmpty() async throws {
    countsByTable = ["coaches": "*/0"]
    let count = try await makeService().exactCount(table: "coaches", column: "family_unit_id", value: "fam-B")
    XCTAssertEqual(count, 0)
  }

  func testExactCount_propagatesServerFailureInsteadOfReportingZero() async throws {
    StubURLProtocol.handler = { request in
      (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
    }
    do {
      _ = try await makeService().exactCount(table: "coaches", column: "family_unit_id", value: "fam-B")
      XCTFail("a failed count must throw, not read as zero")
    } catch {
      XCTAssertTrue(true)
    }
  }
}
