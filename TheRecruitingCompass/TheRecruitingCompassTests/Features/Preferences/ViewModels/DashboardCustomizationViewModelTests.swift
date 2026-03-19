import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DashboardCustomizationViewModelTests: XCTestCase {
  nonisolated deinit {}
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
    // Given — toggleAllStatsCards controls the four live stat cards
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

    // Then — only live cards are toggled
    XCTAssertTrue(viewModel.visibility.statsCards.coaches)
    XCTAssertTrue(viewModel.visibility.statsCards.schools)
    XCTAssertTrue(viewModel.visibility.statsCards.interactions)
    XCTAssertTrue(viewModel.visibility.statsCards.offers)
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testToggleAllStatsCards_DisablesAllCards() {
    // Given
    viewModel.visibility.statsCards = StatsCardVisibility.default

    // When
    viewModel.toggleAllStatsCards(false)

    // Then — only live cards are toggled
    XCTAssertFalse(viewModel.visibility.statsCards.coaches)
    XCTAssertFalse(viewModel.visibility.statsCards.schools)
    XCTAssertFalse(viewModel.visibility.statsCards.interactions)
    XCTAssertFalse(viewModel.visibility.statsCards.offers)
  }



  func testToggleAllWidgets_DisablesAllWidgets() {
    // Given
    viewModel.visibility.widgets = WidgetVisibility.default

    // When
    viewModel.toggleAllWidgets(false)

    // Then — only live widgets are toggled
    XCTAssertFalse(viewModel.visibility.widgets.actionItems)
    XCTAssertFalse(viewModel.visibility.widgets.quickTasks)
    XCTAssertFalse(viewModel.visibility.widgets.atAGlanceSummary)
    XCTAssertFalse(viewModel.visibility.widgets.interactionTrendChart)
    XCTAssertFalse(viewModel.visibility.widgets.eventsSummary)
    XCTAssertFalse(viewModel.visibility.widgets.performanceSummary)
    XCTAssertFalse(viewModel.visibility.widgets.recentActivity)
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
    // Given — disable a live widget (allWidgetsEnabled only checks live widgets)
    viewModel.visibility.widgets = WidgetVisibility.default
    viewModel.visibility.widgets.actionItems = false

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
