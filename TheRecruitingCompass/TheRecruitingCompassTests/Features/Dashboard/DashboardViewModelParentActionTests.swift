import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DashboardViewModelParentActionTests: XCTestCase {
  nonisolated deinit {}

  private func makeSUT() -> (DashboardViewModel, MockDashboardService) {
    let auth = MockAuthManager()
    let service = MockDashboardService()
    let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    let sut = DashboardViewModel(
      authManager: auth,
      dashboardService: service,
      familyManager: family
    )
    return (sut, service)
  }

  func test_dismiss_inParentPreview_stillCallsService() async {
    let (sut, service) = makeSUT()
    XCTAssertTrue(sut.isParentPreviewMode, "fixture should put VM in parent-preview mode")
    await sut.dismissSuggestion("sug-1")
    XCTAssertEqual(service.dismissSuggestionCallCount, 1)
  }

  func test_complete_inParentPreview_stillCallsService() async {
    let (sut, service) = makeSUT()
    XCTAssertTrue(sut.isParentPreviewMode)
    await sut.completeSuggestion("sug-1")
    XCTAssertEqual(service.completeSuggestionCallCount, 1)
  }
}
