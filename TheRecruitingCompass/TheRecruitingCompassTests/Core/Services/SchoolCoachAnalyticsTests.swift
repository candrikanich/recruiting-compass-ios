import Supabase
import XCTest
@testable import TheRecruitingCompass

/// `school_added` / `coach_added` match web: one event per successful insert, none on failure.
/// Each test drives a real service against a stubbed PostgREST response, so a path that skips the
/// capture (or fires it before the insert is known to have succeeded) fails here.
@MainActor
final class SchoolCoachAnalyticsTests: XCTestCase {
  nonisolated deinit {}
  private var harness: AnalyticsHarness!
  private var transport: RecordingTransport { harness.transport }

  override func setUp() {
    super.setUp()
    harness = AnalyticsHarness()
  }

  override func tearDown() {
    StubURLProtocol.handler = nil
    harness.restore()
    harness = nil
    super.tearDown()
  }

  // MARK: - Fixtures

  private func stub(status: Int, body: String) {
    StubURLProtocol.handler = { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: status, httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, Data(body.utf8))
    }
  }

  private func manager() -> SupabaseManager {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return SupabaseManager(client: SupabaseClient(
      supabaseURL: URL(string: "https://example.supabase.co")!,
      supabaseKey: "anon-key",
      options: SupabaseClientOptions(global: .init(session: URLSession(configuration: config)))
    ))
  }

  private func schoolJSON(division: String?) -> String {
    let divisionValue = division.map { "\"\($0)\"" } ?? "null"
    return """
    {"id":"s1","user_id":"u1","name":"State U","division":\(divisionValue),"status":"researching",
     "family_unit_id":"f1","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
    """
  }

  private let coachJSON = """
  {"id":"c1","first_name":"Pat","last_name":"Lee","school_id":"s1","tags":[],"responsiveness_score":0,
   "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
  """

  private let failureBody = #"{"code":"23505","message":"duplicate","details":null,"hint":null}"#

  private func schoolRequest() throws -> SchoolCreateRequest {
    try SchoolCreateRequest(
      userId: "u1", familyUnitId: "f1", name: "State U", location: nil, city: nil, state: nil,
      division: "D1", conference: nil, website: nil, twitterHandle: nil, instagramHandle: nil,
      ncaaId: nil, notes: nil, status: "researching", academicInfo: nil, faviconUrl: nil
    )
  }

  private func coachRequest() throws -> CoachCreateRequest {
    try CoachCreateRequest(
      schoolId: "s1", userId: "u1", familyUnitId: "f1", role: "head", firstName: "Pat", lastName: "Lee"
    )
  }

  // MARK: - Schools

  func testSchoolsRepository_createSchool_capturesSchoolAddedWithDivision() async throws {
    stub(status: 201, body: schoolJSON(division: "D1"))

    _ = try await SchoolsRepositoryImpl(supabaseManager: manager()).createSchool(request: schoolRequest())

    let fired = transport.events(named: "school_added")
    XCTAssertEqual(fired.count, 1)
    XCTAssertEqual(fired.first?.properties["division"] as? String, "D1")
    XCTAssertEqual(fired.first?.properties["platform"] as? String, "ios")
  }

  func testSchoolsRepository_createSchool_withoutDivision_omitsProperty() async throws {
    stub(status: 201, body: schoolJSON(division: nil))

    _ = try await SchoolsRepositoryImpl(supabaseManager: manager()).createSchool(request: schoolRequest())

    let fired = transport.events(named: "school_added")
    XCTAssertEqual(fired.count, 1)
    XCTAssertNil(fired.first?.properties["division"])
  }

  func testSchoolsRepository_createSchool_failure_capturesNothing() async throws {
    stub(status: 409, body: failureBody)

    do {
      _ = try await SchoolsRepositoryImpl(supabaseManager: manager()).createSchool(request: schoolRequest())
      XCTFail("expected the insert to throw")
    } catch {}

    XCTAssertTrue(transport.events(named: "school_added").isEmpty)
  }

  func testEventsService_createSchool_capturesSchoolAddedWithoutDivision() async throws {
    stub(status: 201, body: #"{"id":"s1","name":"State U","location":null}"#)

    _ = try await EventsServiceImpl(supabaseManager: manager())
      .createSchool(name: "State U", location: nil, userId: "u1", familyUnitId: "f1")

    let fired = transport.events(named: "school_added")
    XCTAssertEqual(fired.count, 1)
    XCTAssertNil(fired.first?.properties["division"])
  }

  func testEventsService_createSchool_failure_capturesNothing() async {
    stub(status: 409, body: failureBody)

    _ = try? await EventsServiceImpl(supabaseManager: manager())
      .createSchool(name: "State U", location: nil, userId: "u1", familyUnitId: "f1")

    XCTAssertTrue(transport.events(named: "school_added").isEmpty)
  }

  // MARK: - Coaches

  func testCoachesService_createCoach_capturesCoachAddedWithNoProperties() async throws {
    stub(status: 201, body: coachJSON)

    _ = try await CoachesServiceImpl(supabaseManager: manager()).createCoach(request: coachRequest())

    let fired = transport.events(named: "coach_added")
    XCTAssertEqual(fired.count, 1)
    XCTAssertEqual(Set(fired.first?.properties.keys.map { $0 } ?? []), ["platform"])
  }

  func testCoachesService_createCoach_failure_capturesNothing() async throws {
    stub(status: 409, body: failureBody)

    _ = try? await CoachesServiceImpl(supabaseManager: manager()).createCoach(request: coachRequest())

    XCTAssertTrue(transport.events(named: "coach_added").isEmpty)
  }

  func testInteractionsService_createCoach_capturesCoachAddedWithNoProperties() async throws {
    stub(status: 201, body: coachJSON)

    _ = try await InteractionsServiceImpl(supabaseManager: manager()).createCoach(coachRequest())

    let fired = transport.events(named: "coach_added")
    XCTAssertEqual(fired.count, 1)
    XCTAssertEqual(Set(fired.first?.properties.keys.map { $0 } ?? []), ["platform"])
  }

  func testInteractionsService_createCoach_failure_capturesNothing() async throws {
    stub(status: 409, body: failureBody)

    _ = try? await InteractionsServiceImpl(supabaseManager: manager()).createCoach(coachRequest())

    XCTAssertTrue(transport.events(named: "coach_added").isEmpty)
  }
}
