import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DashboardCustomizationViewModelTests: XCTestCase {
  var viewModel: DashboardCustomizationViewModel!
  var mockService: MockPreferenceManager!

  override func setUp() async throws {
    try await super.setUp()
    mockService = MockPreferenceManager()
    viewModel = DashboardCustomizationViewModel(preferenceService: mockService)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    super.tearDown()
  }

  // MARK: - Load Tests

  func testLoadVisibility_WhenSettingsExist_LoadsData() async {
    // Given
    let expectedVisibility = DashboardWidgetVisibility(
      statsCards: StatsCardVisibility(
        coaches: false,
        schools: true,
        interactions: false,
        offers: true,
        events: false,
        performance: true,
        notifications: false,
        socialMedia: true
      ),
      widgets: WidgetVisibility(
        actionItems: false,
        quickTasks: true,
        atAGlanceSummary: false,
        interactionTrendChart: false,
        eventsSummary: false,
        performanceSummary: true,
        recentActivity: false,
        recentNotifications: false,
        linkedAccounts: true,
        recruitingCalendar: false,
        offerStatusOverview: true,
        schoolInterestChart: true,
        schoolMapWidget: false,
        coachFollowupWidget: true,
        recentDocuments: false,
        interactionStats: true,
        schoolStatusOverview: false,
        coachResponsiveness: true,
        upcomingDeadlines: false
      )
    )
    mockService.fetchPreferencesResult = .success(expectedVisibility)

    // When
    await viewModel.loadVisibility()

    // Then
    XCTAssertEqual(viewModel.visibility, expectedVisibility)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadVisibility_WhenNoSettings_UsesDefaults() async {
    // Given
    mockService.fetchPreferencesResult = .success(nil)

    // When
    await viewModel.loadVisibility()

    // Then
    XCTAssertEqual(viewModel.visibility, DashboardWidgetVisibility.default)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadVisibility_WhenErrorOccurs_SetsErrorMessage() async {
    // Given
    mockService.fetchPreferencesResult = .failure(PreferenceError.fetchFailed("Network error"))

    // When
    await viewModel.loadVisibility()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  // MARK: - Save Tests

  func testSaveVisibility_SavesSuccessfully() async {
    // Given
    mockService.savePreferencesResult = .success(viewModel.visibility)

    // When
    await viewModel.saveVisibility()

    // Then
    XCTAssertEqual(viewModel.saveStatus, .saved)
  }

  func testSaveVisibility_WhenErrorOccurs_SetsErrorMessage() async {
    // Given
    mockService.savePreferencesResult = .failure(PreferenceError.saveFailed("Network error"))

    // When
    await viewModel.saveVisibility()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.saveStatus, .idle)
  }

  // MARK: - Toggle All Tests

  func testToggleAllStatsCards_EnablesAllCards() {
    // Given
    viewModel.visibility.statsCards = StatsCardVisibility(
      coaches: false,
      schools: false,
      interactions: false,
      offers: false,
      events: false,
      performance: false,
      notifications: false,
      socialMedia: false
    )

    // When
    viewModel.toggleAllStatsCards(true)

    // Then
    XCTAssertTrue(viewModel.visibility.statsCards.coaches)
    XCTAssertTrue(viewModel.visibility.statsCards.schools)
    XCTAssertTrue(viewModel.visibility.statsCards.interactions)
    XCTAssertTrue(viewModel.visibility.statsCards.offers)
    XCTAssertTrue(viewModel.visibility.statsCards.events)
    XCTAssertTrue(viewModel.visibility.statsCards.performance)
    XCTAssertTrue(viewModel.visibility.statsCards.notifications)
    XCTAssertTrue(viewModel.visibility.statsCards.socialMedia)
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testToggleAllStatsCards_DisablesAllCards() {
    // Given
    viewModel.visibility.statsCards = StatsCardVisibility.default

    // When
    viewModel.toggleAllStatsCards(false)

    // Then
    XCTAssertFalse(viewModel.visibility.statsCards.coaches)
    XCTAssertFalse(viewModel.visibility.statsCards.schools)
    XCTAssertFalse(viewModel.visibility.statsCards.interactions)
    XCTAssertFalse(viewModel.visibility.statsCards.offers)
    XCTAssertFalse(viewModel.visibility.statsCards.events)
    XCTAssertFalse(viewModel.visibility.statsCards.performance)
    XCTAssertFalse(viewModel.visibility.statsCards.notifications)
    XCTAssertFalse(viewModel.visibility.statsCards.socialMedia)
  }

  func testToggleAllWidgets_EnablesAllWidgets() {
    // Given
    let allDisabled = WidgetVisibility(
      actionItems: false,
      quickTasks: false,
      atAGlanceSummary: false,
      interactionTrendChart: false,
      eventsSummary: false,
      performanceSummary: false,
      recentActivity: false,
      recentNotifications: false,
      linkedAccounts: false,
      recruitingCalendar: false,
      offerStatusOverview: false,
      schoolInterestChart: false,
      schoolMapWidget: false,
      coachFollowupWidget: false,
      recentDocuments: false,
      interactionStats: false,
      schoolStatusOverview: false,
      coachResponsiveness: false,
      upcomingDeadlines: false
    )
    viewModel.visibility.widgets = allDisabled

    // When
    viewModel.toggleAllWidgets(true)

    // Then
    XCTAssertTrue(viewModel.visibility.widgets.recentNotifications)
    XCTAssertTrue(viewModel.visibility.widgets.linkedAccounts)
    XCTAssertTrue(viewModel.visibility.widgets.recruitingCalendar)
    XCTAssertTrue(viewModel.visibility.widgets.quickTasks)
    XCTAssertTrue(viewModel.visibility.widgets.atAGlanceSummary)
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testToggleAllWidgets_DisablesAllWidgets() {
    // Given
    viewModel.visibility.widgets = WidgetVisibility.default

    // When
    viewModel.toggleAllWidgets(false)

    // Then
    XCTAssertFalse(viewModel.visibility.widgets.recentNotifications)
    XCTAssertFalse(viewModel.visibility.widgets.linkedAccounts)
    XCTAssertFalse(viewModel.visibility.widgets.recruitingCalendar)
    XCTAssertFalse(viewModel.visibility.widgets.quickTasks)
    XCTAssertFalse(viewModel.visibility.widgets.atAGlanceSummary)
  }

  // MARK: - Reset Tests

  func testResetToDefaults_ResetsSettingsAndSaves() async {
    // Given
    viewModel.visibility.statsCards.coaches = false
    viewModel.visibility.widgets.recentNotifications = false
    mockService.savePreferencesResult = .success(DashboardWidgetVisibility.default)

    // When
    await viewModel.resetToDefaults()

    // Then
    XCTAssertEqual(viewModel.visibility, DashboardWidgetVisibility.default)
    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
  }

  // MARK: - Computed Properties Tests

  func testAllStatsCardsEnabled_WhenAllEnabled_ReturnsTrue() {
    // Given
    viewModel.visibility.statsCards = StatsCardVisibility.default

    // Then
    XCTAssertTrue(viewModel.allStatsCardsEnabled)
  }

  func testAllStatsCardsEnabled_WhenOneDisabled_ReturnsFalse() {
    // Given
    viewModel.visibility.statsCards = StatsCardVisibility.default
    viewModel.visibility.statsCards.coaches = false

    // Then
    XCTAssertFalse(viewModel.allStatsCardsEnabled)
  }

  func testAllWidgetsEnabled_WhenAllEnabled_ReturnsTrue() {
    // Given
    viewModel.visibility.widgets = WidgetVisibility.default

    // Then
    XCTAssertTrue(viewModel.allWidgetsEnabled)
  }

  func testAllWidgetsEnabled_WhenOneDisabled_ReturnsFalse() {
    // Given
    viewModel.visibility.widgets = WidgetVisibility.default
    viewModel.visibility.widgets.recentNotifications = false

    // Then
    XCTAssertFalse(viewModel.allWidgetsEnabled)
  }

  // MARK: - Individual Toggle Tests

  func testToggleIndividualStatsCard_MarksChanged() {
    // When
    viewModel.visibility.statsCards.coaches = false
    viewModel.markChanged()

    // Then
    XCTAssertFalse(viewModel.visibility.statsCards.coaches)
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testToggleIndividualWidget_MarksChanged() {
    // When
    viewModel.visibility.widgets.recentNotifications = false
    viewModel.markChanged()

    // Then
    XCTAssertFalse(viewModel.visibility.widgets.recentNotifications)
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }
}
