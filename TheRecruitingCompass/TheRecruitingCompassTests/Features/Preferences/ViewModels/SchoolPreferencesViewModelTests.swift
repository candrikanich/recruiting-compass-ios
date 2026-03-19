import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolPreferencesViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: SchoolPreferencesViewModel!
  var mockService: MockPreferenceManager!

  override func setUp() async throws {
    try await super.setUp()
    mockService = MockPreferenceManager()
    viewModel = SchoolPreferencesViewModel(preferenceService: mockService)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    super.tearDown()
  }

  // MARK: - Load/Save Tests

  func testLoadPreferences_WhenPreferencesExist_LoadsData() async {
    // Given
    let expectedPrefs = SchoolPreferences(
      preferences: [
        SchoolPreference(
          id: "1",
          category: .location,
          type: "max_distance_miles",
          value: .int(500),
          priority: 1,
          isDealbreaker: false
        )
      ],
      templateUsed: "Best Fit",
      lastUpdated: "2026-02-12"
    )
    mockService.fetchPreferencesResult = .success(expectedPrefs)

    // When
    await viewModel.loadPreferences()

    // Then
    XCTAssertEqual(viewModel.preferences.preferences.count, 1)
    XCTAssertEqual(viewModel.preferences.templateUsed, "Best Fit")
    XCTAssertFalse(viewModel.isLoading)
  }

  func testSavePreferences_SavesSuccessfully() async {
    // Given
    mockService.savePreferencesResult = .success(viewModel.preferences)

    // When
    await viewModel.savePreferences()

    // Then
    XCTAssertEqual(viewModel.saveStatus, .saved)
  }

  // MARK: - Template Tests

  func testApplyTemplate_D1PowerConference_CreatesCorrectPreferences() {
    // When
    viewModel.requestTemplateApplication("D1 Power Conference")
    viewModel.confirmTemplateApplication()

    // Then
    XCTAssertEqual(viewModel.preferences.preferences.count, 3)
    XCTAssertEqual(viewModel.preferences.templateUsed, "D1 Power Conference")
    XCTAssertEqual(viewModel.saveStatus, .saving)

    // Verify first preference (Division: D1)
    let first = viewModel.preferences.preferences[0]
    XCTAssertEqual(first.category, .program)
    XCTAssertEqual(first.type, "division")
    XCTAssertEqual(first.priority, 1)
  }

  func testApplyTemplate_AcademicExcellence_CreatesCorrectPreferences() {
    // When
    viewModel.requestTemplateApplication("Academic Excellence")
    viewModel.confirmTemplateApplication()

    // Then
    XCTAssertEqual(viewModel.preferences.preferences.count, 3)
    XCTAssertEqual(viewModel.preferences.templateUsed, "Academic Excellence")

    // Verify academic rating preference
    let first = viewModel.preferences.preferences[0]
    XCTAssertEqual(first.category, .academic)
    XCTAssertEqual(first.type, "min_academic_rating")
  }

  func testApplyTemplate_CloseToHome_CreatesSinglePreference() {
    // When
    viewModel.requestTemplateApplication("Close to Home")
    viewModel.confirmTemplateApplication()

    // Then
    XCTAssertEqual(viewModel.preferences.preferences.count, 1)
    XCTAssertEqual(viewModel.preferences.preferences[0].type, "max_distance_miles")
  }

  func testApplyTemplate_WithExistingPreferences_ShowsWarning() {
    // Given
    viewModel.preferences.preferences = [
      SchoolPreference(
        id: "1",
        category: .location,
        type: "max_distance_miles",
        value: .int(100),
        priority: 1,
        isDealbreaker: false
      )
    ]

    // When
    viewModel.requestTemplateApplication("D1 Power Conference")

    // Then
    XCTAssertTrue(viewModel.showingTemplateWarning)
    XCTAssertEqual(viewModel.pendingTemplate, "D1 Power Conference")
    // Preferences should not change until confirmed
    XCTAssertEqual(viewModel.preferences.preferences.count, 1)
  }

  func testCancelTemplateApplication_ClearsWarning() {
    // Given - Need existing preferences to trigger the warning path
    viewModel.preferences.preferences = [
      SchoolPreference(
        id: "1",
        category: .location,
        type: "max_distance_miles",
        value: .int(100),
        priority: 1,
        isDealbreaker: false
      )
    ]
    viewModel.requestTemplateApplication("D1 Power Conference")
    XCTAssertTrue(viewModel.showingTemplateWarning)

    // When
    viewModel.cancelTemplateApplication()

    // Then
    XCTAssertFalse(viewModel.showingTemplateWarning)
    XCTAssertNil(viewModel.pendingTemplate)
  }

  // MARK: - Preference Management Tests

  func testAddPreference_AddsToList() {
    // Given
    let preference = SchoolPreference(
      id: UUID().uuidString,
      category: .location,
      type: "max_distance_miles",
      value: .int(500),
      priority: 0,
      isDealbreaker: false
    )

    // When
    viewModel.addPreference(preference)

    // Then
    XCTAssertEqual(viewModel.preferences.preferences.count, 1)
    XCTAssertEqual(viewModel.preferences.preferences[0].priority, 1)
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testRemovePreference_RemovesFromList() {
    // Given
    viewModel.preferences.preferences = [
      SchoolPreference(id: "1", category: .location, type: "max_distance_miles", value: .int(500), priority: 1, isDealbreaker: false),
      SchoolPreference(id: "2", category: .academic, type: "min_academic_rating", value: .int(4), priority: 2, isDealbreaker: false)
    ]

    // When
    viewModel.removePreference(at: IndexSet(integer: 0))

    // Then
    XCTAssertEqual(viewModel.preferences.preferences.count, 1)
    XCTAssertEqual(viewModel.preferences.preferences[0].id, "2")
    XCTAssertEqual(viewModel.preferences.preferences[0].priority, 1) // Priority updated
  }

  func testMovePreference_ReordersList() {
    // Given
    viewModel.preferences.preferences = [
      SchoolPreference(id: "1", category: .location, type: "max_distance_miles", value: .int(500), priority: 1, isDealbreaker: false),
      SchoolPreference(id: "2", category: .academic, type: "min_academic_rating", value: .int(4), priority: 2, isDealbreaker: false),
      SchoolPreference(id: "3", category: .program, type: "division", value: .stringArray(["D1"]), priority: 3, isDealbreaker: false)
    ]

    // When - Move item 0 to position 2
    viewModel.movePreference(from: IndexSet(integer: 0), to: 2)

    // Then
    XCTAssertEqual(viewModel.preferences.preferences[0].id, "2")
    XCTAssertEqual(viewModel.preferences.preferences[1].id, "1")
    XCTAssertEqual(viewModel.preferences.preferences[2].id, "3")

    // Verify priorities updated
    XCTAssertEqual(viewModel.preferences.preferences[0].priority, 1)
    XCTAssertEqual(viewModel.preferences.preferences[1].priority, 2)
    XCTAssertEqual(viewModel.preferences.preferences[2].priority, 3)
  }

  func testToggleDealbreaker_TogglesFlag() {
    // Given
    viewModel.preferences.preferences = [
      SchoolPreference(id: "1", category: .location, type: "max_distance_miles", value: .int(500), priority: 1, isDealbreaker: false)
    ]

    // When
    viewModel.toggleDealbreaker(id: "1")

    // Then
    XCTAssertTrue(viewModel.preferences.preferences[0].isDealbreaker)
    XCTAssertEqual(viewModel.saveStatus, .saving)

    // When - Toggle again
    viewModel.toggleDealbreaker(id: "1")

    // Then
    XCTAssertFalse(viewModel.preferences.preferences[0].isDealbreaker)
  }

  // MARK: - Computed Properties Tests

  func testHasPreferences_WhenEmpty_ReturnsFalse() {
    XCTAssertFalse(viewModel.hasPreferences)
  }

  func testHasPreferences_WhenNotEmpty_ReturnsTrue() {
    // Given
    viewModel.preferences.preferences = [
      SchoolPreference(id: "1", category: .location, type: "max_distance_miles", value: .int(500), priority: 1, isDealbreaker: false)
    ]

    // Then
    XCTAssertTrue(viewModel.hasPreferences)
  }

  // MARK: - Integration Tests

  func testCompleteWorkflow_LoadApplyTemplateModifySave() async {
    // Given
    mockService.fetchPreferencesResult = .success(nil)
    mockService.savePreferencesResult = .success(viewModel.preferences)

    // When - Load
    await viewModel.loadPreferences()
    XCTAssertFalse(viewModel.hasPreferences)

    // When - Apply template
    viewModel.requestTemplateApplication("Best Fit (Balanced)")
    viewModel.confirmTemplateApplication()
    XCTAssertEqual(viewModel.preferences.preferences.count, 3)
    XCTAssertEqual(viewModel.saveStatus, .saving)

    // When - Toggle dealbreaker
    viewModel.toggleDealbreaker(id: viewModel.preferences.preferences[0].id)
    XCTAssertTrue(viewModel.preferences.preferences[0].isDealbreaker)

    // When - Save
    await viewModel.savePreferences()
    XCTAssertEqual(viewModel.saveStatus, .saved)
    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
  }
}
