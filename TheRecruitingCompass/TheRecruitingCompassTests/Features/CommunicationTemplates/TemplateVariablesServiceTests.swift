import XCTest
@testable import TheRecruitingCompass

final class TemplateVariablesServiceTests: XCTestCase {
  func test_cachesFirstSuccessfulFetch() async throws {
    let counter = FetchCounter()
    let sut = TemplateVariablesServiceImpl(fetch: {
      await counter.bump()
      return [TemplateVariableDef(key: "playerName", label: "Player Name",
                                  category: "player", sourceType: .column,
                                  sourcePath: "column:users.full_name")]
    })
    let first = try await sut.fetchRegistry()
    let second = try await sut.fetchRegistry()
    XCTAssertEqual(first.map(\.key), ["playerName"])
    XCTAssertEqual(second.map(\.key), ["playerName"])
    let calls = await counter.count
    XCTAssertEqual(calls, 1, "second call served from cache")
  }

  func test_missingTableFailsOpenToEmpty() async throws {
    struct StubErr: LocalizedError { var errorDescription: String? { "PGRST205 not found" } }
    let sut = TemplateVariablesServiceImpl(fetch: { throw StubErr() })
    let result = try await sut.fetchRegistry()
    XCTAssertTrue(result.isEmpty, "missing table degrades to empty, never throws")
  }
}

private actor FetchCounter {
  private(set) var count = 0
  func bump() { count += 1 }
}
