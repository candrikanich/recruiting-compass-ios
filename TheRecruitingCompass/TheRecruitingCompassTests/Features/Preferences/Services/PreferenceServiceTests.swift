import XCTest
@testable import TheRecruitingCompass

@MainActor
final class PreferenceServiceTests: XCTestCase {
  var mockManager: MockPreferenceManager!

  override func setUp() {
    super.setUp()
    mockManager = MockPreferenceManager()
  }

  override func tearDown() {
    mockManager = nil
    super.tearDown()
  }

  // MARK: - Fetch Tests

  func testFetchPreferences_WhenPreferencesExist_ReturnsData() async throws {
    // Given
    let expectedSettings = NotificationSettings.default
    mockManager.fetchPreferencesResult = .success(expectedSettings)

    // When
    let result: NotificationSettings? = try await mockManager.fetchPreferences(category: .notifications)

    // Then
    XCTAssertEqual(result, expectedSettings)
    XCTAssertEqual(mockManager.fetchPreferencesCalls.count, 1)
    XCTAssertEqual(mockManager.fetchPreferencesCalls.first, .notifications)
  }

  func testFetchPreferences_WhenNoPreferences_ReturnsNil() async throws {
    // Given
    mockManager.fetchPreferencesResult = .success(nil)

    // When
    let result: NotificationSettings? = try await mockManager.fetchPreferences(category: .notifications)

    // Then
    XCTAssertNil(result)
  }

  func testFetchPreferences_WhenErrorOccurs_ThrowsError() async {
    // Given
    mockManager.fetchPreferencesResult = .failure(PreferenceError.fetchFailed("Network error"))

    // When/Then
    do {
      let _: NotificationSettings? = try await mockManager.fetchPreferences(category: .notifications)
      XCTFail("Should have thrown an error")
    } catch {
      XCTAssertTrue(error is PreferenceError)
    }
  }

  // MARK: - Save Tests

  func testSavePreferences_SavesDataSuccessfully() async throws {
    // Given
    let settings = NotificationSettings.default
    mockManager.savePreferencesResult = .success(settings)

    // When
    let result = try await mockManager.savePreferences(category: .notifications, data: settings)

    // Then
    XCTAssertEqual(result, settings)
    XCTAssertEqual(mockManager.savePreferencesCalls.count, 1)
    XCTAssertEqual(mockManager.savePreferencesCalls.first?.category, .notifications)
  }

  func testSavePreferences_WhenErrorOccurs_ThrowsError() async {
    // Given
    let settings = NotificationSettings.default
    mockManager.savePreferencesResult = .failure(PreferenceError.saveFailed("Network error"))

    // When/Then
    do {
      _ = try await mockManager.savePreferences(category: .notifications, data: settings)
      XCTFail("Should have thrown an error")
    } catch {
      XCTAssertTrue(error is PreferenceError)
    }
  }

  // MARK: - Delete Tests

  func testDeletePreferences_DeletesSuccessfully() async throws {
    // When
    try await mockManager.deletePreferences(category: .notifications)

    // Then
    XCTAssertTrue(mockManager.deletePreferencesCalled)
    XCTAssertEqual(mockManager.deletePreferencesCalls.count, 1)
    XCTAssertEqual(mockManager.deletePreferencesCalls.first, .notifications)
  }

  // MARK: - Model Default Tests

  func testNotificationSettings_DefaultValues() {
    let defaults = NotificationSettings.default

    XCTAssertEqual(defaults.followUpReminderDays, 7)
    XCTAssertTrue(defaults.enableFollowUpReminders)
    XCTAssertTrue(defaults.enableDeadlineAlerts)
    XCTAssertTrue(defaults.enableDailyDigest)
    XCTAssertTrue(defaults.enableInboundInteractionAlerts)
    XCTAssertTrue(defaults.enableEmailNotifications)
    XCTAssertFalse(defaults.emailOnlyHighPriority)
    XCTAssertNil(defaults.quietHoursStart)
    XCTAssertNil(defaults.quietHoursEnd)
  }

  func testHomeLocation_DefaultValues() {
    let defaults = HomeLocation.default

    XCTAssertNil(defaults.address)
    XCTAssertNil(defaults.city)
    XCTAssertNil(defaults.state)
    XCTAssertNil(defaults.zip)
    XCTAssertNil(defaults.latitude)
    XCTAssertNil(defaults.longitude)
  }

  func testPlayerDetails_DefaultValues() {
    let defaults = PlayerDetails.default

    XCTAssertNil(defaults.graduationYear)
    XCTAssertNil(defaults.highSchool)
    XCTAssertNil(defaults.clubTeam)
    XCTAssertNil(defaults.primarySport)
    XCTAssertNil(defaults.primaryPosition)
  }

  func testSchoolPreferences_DefaultValues() {
    let defaults = SchoolPreferences.default

    XCTAssertEqual(defaults.preferences.count, 0)
    XCTAssertNil(defaults.templateUsed)
    XCTAssertNotNil(defaults.lastUpdated)
  }

  func testDashboardWidgetVisibility_DefaultValues() {
    let defaults = DashboardWidgetVisibility.default

    // Stats cards
    XCTAssertTrue(defaults.statsCards.coaches)
    XCTAssertTrue(defaults.statsCards.schools)
    XCTAssertTrue(defaults.statsCards.interactions)

    // Widgets
    XCTAssertTrue(defaults.widgets.recentNotifications)
    XCTAssertTrue(defaults.widgets.linkedAccounts)
    XCTAssertTrue(defaults.widgets.recruitingCalendar)
  }

  // MARK: - Codable Tests

  func testNotificationSettings_EncodesAndDecodes() throws {
    let original = NotificationSettings(
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

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(NotificationSettings.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testHomeLocation_EncodesAndDecodes() throws {
    let original = HomeLocation(
      address: "123 Main St",
      city: "Springfield",
      state: "IL",
      zip: "62701",
      latitude: 39.7817,
      longitude: -89.6501
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(HomeLocation.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testPlayerDetails_EncodesAndDecodes() throws {
    let original = PlayerDetails(
      graduationYear: 2026,
      highSchool: "Springfield High",
      clubTeam: "Elite Baseball",
      primarySport: "Baseball",
      primaryPosition: "Pitcher",
      positions: ["Pitcher", "First Base"],
      bats: "R",
      throws_: "R",
      heightInches: 72,
      weightLbs: 180,
      gpa: 3.8,
      satScore: 1350,
      actScore: 30,
      ncaaId: "123456",
      perfectGameId: "PG789",
      prepBaseballId: "PB101",
      twitterHandle: "@player",
      instagramHandle: "@player",
      tiktokHandle: "@player",
      facebookUrl: "https://facebook.com/player",
      phone: "555-1234",
      email: "player@example.com",
      allowSharePhone: true,
      allowShareEmail: false,
      schoolName: "Springfield High School",
      schoolAddress: "456 School Rd",
      schoolCity: "Springfield",
      schoolState: "IL",
      ninthGradeTeam: "JV Team",
      ninthGradeCoach: "Coach A",
      tenthGradeTeam: "Varsity",
      tenthGradeCoach: "Coach B",
      eleventhGradeTeam: "Varsity",
      eleventhGradeCoach: "Coach C",
      twelfthGradeTeam: "Varsity",
      twelfthGradeCoach: "Coach D",
      travelTeamYear: 2025,
      travelTeamName: "Elite Travel",
      travelTeamCoach: "Coach E"
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(PlayerDetails.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testSchoolPreferences_EncodesAndDecodes() throws {
    let preference = SchoolPreference(
      id: "pref-1",
      category: .location,
      type: "max_distance_miles",
      value: .int(500),
      priority: 1,
      isDealbreaker: false
    )

    let original = SchoolPreferences(
      preferences: [preference],
      templateUsed: "close_to_home",
      lastUpdated: "2026-02-12T00:00:00Z"
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SchoolPreferences.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testDashboardWidgetVisibility_EncodesAndDecodes() throws {
    let original = DashboardWidgetVisibility(
      statsCards: StatsCardVisibility(
        coaches: true,
        schools: false,
        interactions: true,
        offers: false,
        events: true,
        performance: false,
        notifications: true,
        socialMedia: false
      ),
      widgets: WidgetVisibility(
        recentNotifications: true,
        linkedAccounts: false,
        recruitingCalendar: true,
        quickTasks: false,
        atAGlanceSummary: true,
        offerStatusOverview: false,
        interactionTrendChart: true,
        schoolInterestChart: false,
        schoolMapWidget: true,
        coachFollowupWidget: false,
        eventsSummary: true,
        performanceSummary: false,
        recentDocuments: true,
        interactionStats: false,
        schoolStatusOverview: true,
        coachResponsiveness: false,
        upcomingDeadlines: true
      )
    )

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(DashboardWidgetVisibility.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  // MARK: - AnyCodableValue Tests

  func testAnyCodableValue_StringValue() throws {
    let original = AnyCodableValue.string("test")
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testAnyCodableValue_IntValue() throws {
    let original = AnyCodableValue.int(42)
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testAnyCodableValue_BoolValue() throws {
    let original = AnyCodableValue.bool(true)
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }

  func testAnyCodableValue_StringArrayValue() throws {
    let original = AnyCodableValue.stringArray(["a", "b", "c"])
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: encoded)

    XCTAssertEqual(decoded, original)
  }
}
