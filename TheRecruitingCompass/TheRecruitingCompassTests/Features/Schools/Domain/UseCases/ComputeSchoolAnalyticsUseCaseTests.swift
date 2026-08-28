import XCTest
@testable import TheRecruitingCompass

final class ComputeSchoolAnalyticsUseCaseTests: XCTestCase {
  nonisolated deinit {}

  private let sut = ComputeSchoolAnalyticsUseCase()

  func testCounts_favoritesVisitedContacted() {
    let schools = [
      makeSchool(id: "1", isFavorite: true),
      makeSchool(id: "2", isFavorite: false),
      makeSchool(id: "3", isFavorite: true)
    ]

    let analytics = sut.execute(
      schools: schools,
      visitedSchoolIds: ["1"],
      contactedSchoolIds: ["1", "2"]
    )

    XCTAssertEqual(analytics.totalCount, 3)
    XCTAssertEqual(analytics.favoritesCount, 2)
    XCTAssertEqual(analytics.visitedCount, 1)
    XCTAssertEqual(analytics.contactedCount, 2)
  }

  func testEmptyList_zeros() {
    let analytics = sut.execute(schools: [], visitedSchoolIds: ["x"], contactedSchoolIds: ["x"])
    XCTAssertEqual(analytics, SchoolAnalytics(totalCount: 0, favoritesCount: 0, visitedCount: 0, contactedCount: 0))
  }

  private func makeSchool(id: String, isFavorite: Bool) -> School {
    School(
      id: id,
      userId: "user-1",
      name: "School",
      location: nil,
      city: nil,
      state: nil,
      division: "D1",
      conference: nil,
      ranking: nil,
      isFavorite: isFavorite,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "interested",
      statusChangedAt: nil,
      notes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: nil,
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      familyUnitId: "family-1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }
}
