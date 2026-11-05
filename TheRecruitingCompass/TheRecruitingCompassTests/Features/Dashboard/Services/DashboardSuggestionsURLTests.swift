import XCTest
@testable import TheRecruitingCompass

/// The Action Items widget must ask for the selected athlete's suggestions; without `athleteId` the server
/// answers for whichever athlete is closest to graduation across all of a parent's families (#228 / #530).
final class DashboardSuggestionsURLTests: XCTestCase {
  private final class Captured: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URL] = []
    func record(_ url: URL) { lock.withLock { stored.append(url) } }
    var urls: [URL] { lock.withLock { stored } }
  }

  private var captured = Captured()

  override func setUp() {
    super.setUp()
    captured = Captured()
    let captured = captured
    StubURLProtocol.handler = { request in
      captured.record(request.url!)
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data(#"{"suggestions":[],"pending_count":0}"#.utf8))
    }
  }

  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  func testFetchSuggestions_sendsTheSelectedAthleteIdAndLocation() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let service = DashboardServiceImpl(
      supabaseManager: .shared,
      session: URLSession(configuration: config),
      baseURLOverride: URL(string: "https://api.test.invalid")
    )

    _ = try await service.fetchSuggestions(location: "dashboard", athleteId: "ath-selected", accessToken: "tok")

    let url = try XCTUnwrap(captured.urls.first)
    XCTAssertEqual(url.path, "/api/suggestions")
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    XCTAssertEqual(items.first { $0.name == "athleteId" }?.value, "ath-selected")
    XCTAssertEqual(items.first { $0.name == "location" }?.value, "dashboard")
  }
}
