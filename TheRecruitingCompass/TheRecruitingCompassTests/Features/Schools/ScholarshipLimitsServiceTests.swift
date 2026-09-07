import XCTest
@testable import TheRecruitingCompass

struct MockScholarshipLimitsService: ScholarshipLimitsServicing {
  let limits: [ScholarshipLimit]
  func fetchLimits() async throws -> [ScholarshipLimit] { limits }
}

final class ScholarshipLimitsServiceTests: XCTestCase {
  func test_mockReturnsInjectedLimits() async throws {
    let svc = MockScholarshipLimitsService(limits: [
      ScholarshipLimit(sport: "Baseball", division: "D1", total: 11.7, headCount: nil, equivalency: 11.7, notes: nil)
    ])
    let limits = try await svc.fetchLimits()
    XCTAssertEqual(limits.count, 1)
    XCTAssertEqual(limits.first?.division, "D1")
  }

  func test_implCachesAfterFirstFetch() async throws {
    var callCount = 0
    let svc = ScholarshipLimitsServiceImpl(fetch: {
      callCount += 1
      return [ScholarshipLimit(sport: "Baseball", division: "D1", total: 11.7, headCount: nil, equivalency: 11.7, notes: nil)]
    })
    _ = try await svc.fetchLimits()
    _ = try await svc.fetchLimits()
    XCTAssertEqual(callCount, 1)
  }

  func test_implFailsOpenOnFetchError() async throws {
    let svc = ScholarshipLimitsServiceImpl(fetch: {
      throw NSError(domain: "test", code: 1)
    })
    let limits = try await svc.fetchLimits()
    XCTAssertTrue(limits.isEmpty)
  }
}
