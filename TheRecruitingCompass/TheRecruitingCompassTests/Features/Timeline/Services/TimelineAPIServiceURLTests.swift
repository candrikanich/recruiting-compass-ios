import XCTest
@testable import TheRecruitingCompass

/// Pins the wire contract: without `athleteId` the server picks the athlete closest to graduation across ALL of a
/// parent's families, so the selected athlete must reach the URL (#228 / #530), not just the protocol call.
final class TimelineAPIServiceURLTests: XCTestCase {
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
      return (response, Data("[]".utf8))
    }
  }

  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  private func makeService() -> TimelineAPIService {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return TimelineAPIService(
      session: URLSession(configuration: config),
      baseURLOverride: URL(string: "https://api.test.invalid")
    )
  }

  private func sentAthleteId(path: String) throws -> String? {
    let url = try XCTUnwrap(captured.urls.first)
    XCTAssertEqual(url.path, path)
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first { $0.name == "athleteId" }?.value
  }

  func testFetchPhase_sendsTheSelectedAthleteId() async throws {
    _ = try? await makeService().fetchPhase(accessToken: "tok", athleteId: "ath-selected")
    XCTAssertEqual(try sentAthleteId(path: "/api/athlete/phase"), "ath-selected")
  }

  func testFetchStatus_sendsTheSelectedAthleteId() async throws {
    _ = try? await makeService().fetchStatus(accessToken: "tok", athleteId: "ath-selected")
    XCTAssertEqual(try sentAthleteId(path: "/api/athlete/status"), "ath-selected")
  }

  func testFetchWhatMattersNow_sendsTheSelectedAthleteId() async throws {
    _ = try await makeService().fetchWhatMattersNow(accessToken: "tok", athleteId: "ath-selected")
    XCTAssertEqual(try sentAthleteId(path: "/api/athlete/what-matters-now"), "ath-selected")
  }
}
