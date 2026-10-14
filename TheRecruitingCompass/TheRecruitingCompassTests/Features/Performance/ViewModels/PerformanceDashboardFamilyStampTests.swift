import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PerformanceDashboardFamilyStampTests: XCTestCase {
  nonisolated deinit {}

  func testAddMetric_stampsActiveFamilyUnitId() async {
    let mockService = MockPerformanceService()
    let mockAuth = MockAuthManager()
    let familyManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: mockAuth)
    let viewModel = PerformanceDashboardViewModel(
      performanceService: mockService,
      familyManager: familyManager,
      authManager: mockAuth,
      cache: InMemoryCache()
    )
    viewModel.addFormState.metricType = .velocity
    viewModel.addFormState.value = "92.5"

    await viewModel.addMetric()

    XCTAssertEqual(mockService.lastCreateUserId, ParentViewingAthleteFixture.athleteUserId)
    XCTAssertEqual(mockService.lastCreateFamilyUnitId, ParentViewingAthleteFixture.familyUnitId)
  }
}
