import XCTest
@testable import TheRecruitingCompass

/// Web counts iOS traffic by version from `X-Client-*`; a request without them lands in the "legacy (<=1.0)" bucket.
final class ClientHeadersGuardTests: XCTestCase {
  private static var sourceRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("TheRecruitingCompass")
  }

  func test_everyFileBuildingURLRequests_addsClientHeadersForEachRequest() throws {
    let files = try XCTUnwrap(
      FileManager.default.enumerator(at: Self.sourceRoot, includingPropertiesForKeys: nil)
    ).compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    XCTAssertFalse(files.isEmpty, "source root not found: \(Self.sourceRoot.path)")

    var offenders: [String] = []
    for file in files where file.lastPathComponent != "AppInfo.swift" {
      let text = try String(contentsOf: file, encoding: .utf8)
      let requests = text.components(separatedBy: "URLRequest(").count - 1
      let headered = text.components(separatedBy: "addClientHeaders()").count - 1
      let shortcuts = text.components(separatedBy: "URLSession.shared.data(from:").count - 1
      if requests > headered || (shortcuts > 0 && text.contains("api/")) {
        offenders.append("\(file.lastPathComponent): \(requests) requests, \(headered) with client headers")
      }
    }
    XCTAssertEqual(offenders, [], "New /api requests must call request.addClientHeaders()")
  }

  func test_collegeSearch_sendsClientHeaders() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    nonisolated(unsafe) var captured: URLRequest?
    StubURLProtocol.handler = { request in
      captured = request
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data(#"{"metadata":{"total":0,"page":0,"per_page":20},"results":[]}"#.utf8))
    }
    defer { StubURLProtocol.handler = nil }
    let service = CollegeScorecardService(
      urlSession: URLSession(configuration: config),
      baseURL: URL(string: "https://test.local")!,
      tokenProvider: { "tok" }
    )
    _ = try? await service.searchColleges(query: "Florida")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Client-Platform"), "ios")
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Client-Version"), AppInfo.version)
    XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Client-Build"), AppInfo.build)
  }
}
