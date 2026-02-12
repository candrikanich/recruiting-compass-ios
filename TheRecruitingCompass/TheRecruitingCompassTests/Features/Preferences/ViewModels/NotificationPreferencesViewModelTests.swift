import XCTest
@testable import TheRecruitingCompass

@MainActor
final class NotificationPreferencesViewModelTests: XCTestCase {
  var viewModel: NotificationPreferencesViewModel!
  var mockService: MockPreferenceManager!

  override func setUp() async throws {
    try await super.setUp()
    mockService = MockPreferenceManager()
    viewModel = NotificationPreferencesViewModel(preferenceService: mockService)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    super.tearDown()
  }

  // MARK: - Load Tests

  func testLoadPreferences_WhenPreferencesExist_LoadsSettings() async {
    // Given
    let expectedSettings = NotificationSettings(
      followUpReminderDays: 14,
      enableFollowUpReminders: false,
      enableDeadlineAlerts: true,
      enableDailyDigest: false,
      enableInboundInteractionAlerts: true,
      enableEmailNotifications: false,
      emailOnlyHighPriority: true,
      quietHoursStart: "22:00",
      quietHoursEnd: "08:00"
    )
    mockService.fetchPreferencesResult = .success(expectedSettings)

    // When
    await viewModel.loadPreferences()

    // Then
    XCTAssertEqual(viewModel.settings, expectedSettings)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(mockService.fetchPreferencesCalls.count, 1)
  }

  func testLoadPreferences_WhenNoPreferences_UsesDefaults() async {
    // Given
    mockService.fetchPreferencesResult = .success(nil)

    // When
    await viewModel.loadPreferences()

    // Then
    XCTAssertEqual(viewModel.settings, NotificationSettings.default)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadPreferences_WhenErrorOccurs_SetsErrorMessage() async {
    // Given
    mockService.fetchPreferencesResult = .failure(PreferenceError.fetchFailed("Network error"))

    // When
    await viewModel.loadPreferences()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to load preferences") ?? false)
    XCTAssertFalse(viewModel.isLoading)
  }

  // MARK: - Save Tests

  func testSavePreferences_SavesSuccessfully() async {
    // Given
    mockService.savePreferencesResult = .success(viewModel.settings)
    viewModel.hasUnsavedChanges = true

    // When
    await viewModel.savePreferences()

    // Then
    XCTAssertFalse(viewModel.hasUnsavedChanges)
    XCTAssertEqual(viewModel.successMessage, "Preferences saved successfully")
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isSaving)
    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
  }

  func testSavePreferences_WhenErrorOccurs_SetsErrorMessage() async {
    // Given
    mockService.savePreferencesResult = .failure(PreferenceError.saveFailed("Network error"))

    // When
    await viewModel.savePreferences()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to save preferences") ?? false)
    XCTAssertFalse(viewModel.isSaving)
  }

  // MARK: - Reset Tests

  func testResetToDefaults_ResetsSettingsAndSaves() async {
    // Given
    viewModel.settings.followUpReminderDays = 30
    viewModel.settings.enableFollowUpReminders = false
    mockService.savePreferencesResult = .success(NotificationSettings.default)

    // When
    await viewModel.resetToDefaults()

    // Then
    XCTAssertEqual(viewModel.settings, NotificationSettings.default)
    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
  }

  // MARK: - Field Update Tests

  func testMarkAsChanged_SetsHasUnsavedChanges() {
    // Given
    XCTAssertFalse(viewModel.hasUnsavedChanges)

    // When
    viewModel.markAsChanged()

    // Then
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testToggleFollowUpReminders_UpdatesSetting() {
    // Given
    let initialValue = viewModel.settings.enableFollowUpReminders

    // When
    viewModel.settings.enableFollowUpReminders.toggle()
    viewModel.markAsChanged()

    // Then
    XCTAssertNotEqual(viewModel.settings.enableFollowUpReminders, initialValue)
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testUpdateFollowUpReminderDays_UpdatesSetting() {
    // Given
    let newValue = 21

    // When
    viewModel.settings.followUpReminderDays = newValue
    viewModel.markAsChanged()

    // Then
    XCTAssertEqual(viewModel.settings.followUpReminderDays, newValue)
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  func testToggleEmailNotifications_UpdatesSetting() {
    // Given
    let initialValue = viewModel.settings.enableEmailNotifications

    // When
    viewModel.settings.enableEmailNotifications.toggle()
    viewModel.markAsChanged()

    // Then
    XCTAssertNotEqual(viewModel.settings.enableEmailNotifications, initialValue)
    XCTAssertTrue(viewModel.hasUnsavedChanges)
  }

  // MARK: - Integration Tests

  func testFullWorkflow_LoadModifySave() async {
    // Given
    let initialSettings = NotificationSettings.default
    mockService.fetchPreferencesResult = .success(initialSettings)
    mockService.savePreferencesResult = .success(initialSettings)

    // When - Load
    await viewModel.loadPreferences()
    XCTAssertEqual(viewModel.settings, initialSettings)

    // When - Modify
    viewModel.settings.followUpReminderDays = 14
    viewModel.markAsChanged()
    XCTAssertTrue(viewModel.hasUnsavedChanges)

    // When - Save
    await viewModel.savePreferences()

    // Then
    XCTAssertFalse(viewModel.hasUnsavedChanges)
    XCTAssertEqual(mockService.savePreferencesCalls.count, 1)
  }
}
