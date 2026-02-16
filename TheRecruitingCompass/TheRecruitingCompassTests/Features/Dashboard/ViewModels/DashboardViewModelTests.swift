import XCTest
@testable import TheRecruitingCompass

@MainActor
final class DashboardViewModelTests: XCTestCase {
  var sut: DashboardViewModel!
  var mockAuthManager: MockAuthManager!
  var mockDashboardService: MockDashboardService!
  var mockTaskStorage: MockQuickTaskStorage!
  var mockFamilyService: MockFamilyService!
  var familyManager: FamilyManager!

  override func setUp() {
    super.setUp()
    mockAuthManager = MockAuthManager()
    mockDashboardService = MockDashboardService()
    mockTaskStorage = MockQuickTaskStorage()
    mockFamilyService = MockFamilyService()
    familyManager = FamilyManager(
      familyService: mockFamilyService,
      authManager: mockAuthManager
    )
    sut = DashboardViewModel(
      authManager: mockAuthManager,
      dashboardService: mockDashboardService,
      taskStorage: mockTaskStorage,
      familyManager: familyManager
    )
  }

  override func tearDown() {
    sut = nil
    mockAuthManager = nil
    mockDashboardService = nil
    mockTaskStorage = nil
    mockFamilyService = nil
    familyManager = nil
    super.tearDown()
  }

  // MARK: - Test Helpers

  private func authenticateUser(
    id: String = "test-user-id",
    email: String = "john@example.com"
  ) {
    let user = User(
      id: id,
      email: email,
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil
    )
    mockAuthManager.setMockUser(user)
  }

  private func setSession(accessToken: String = "test-access-token-1234567890abcdef") {
    let session = Session(
      accessToken: accessToken,
      tokenType: "bearer",
      expiresIn: 3600,
      expiresAt: Int(Date().timeIntervalSince1970) + 3600,
      refreshToken: "test-refresh-token",
      user: mockAuthManager.user!
    )
    mockAuthManager.setMockSession(session)
  }

  private func makeSuggestion(id: String = "suggestion-1") -> Suggestion {
    Suggestion(
      id: id,
      title: "Test Suggestion",
      description: "Test description",
      urgency: .medium,
      actionUrl: nil,
      location: "dashboard",
      createdAt: "2024-01-01T00:00:00Z"
    )
  }

  private func makeInteraction(id: String, date: String) -> Interaction {
    Interaction(
      id: id,
      type: .email,
      direction: .outbound,
      schoolId: nil,
      coachId: nil,
      subject: nil,
      content: nil,
      sentiment: nil,
      occurredAt: date,
      loggedBy: "test-user-id",
      attachments: nil,
      familyUnitId: "family1",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z"
    )
  }

  private func makeParentMember() -> FamilyMember {
    FamilyMember(
      id: "parent-member-id",
      userId: "test-user-id",
      familyUnitId: "family-unit-1",
      role: "parent",
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
  }

  private func makeAthleteMember(
    id: String = "athlete-member-id",
    userId: String = "athlete-user-id"
  ) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: userId,
      familyUnitId: "family-unit-1",
      role: "athlete",
      addedAt: "2024-01-01T00:00:00Z",
      user: FamilyMemberUser(id: userId, email: "alex@example.com", fullName: "Alex Doe", role: "athlete")
    )
  }

  private func setupFamilyContext(userId: String = "test-user-id", role: String = "parent") {
    let familyUnit = FamilyUnit(
      id: "family-unit-1",
      playerUserId: userId,
      familyName: "Test Family",
      familyCode: "FAM-123",
      codeGeneratedAt: "2024-01-01T00:00:00Z",
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      homeLatitude: nil,
      homeLongitude: nil
    )
    mockFamilyService.stubbedFamilyUnit = familyUnit

    let currentMember = FamilyMember(
      id: "\(role)-member-id",
      userId: userId,
      familyUnitId: "family-unit-1",
      role: role,
      addedAt: "2024-01-01T00:00:00Z",
      user: nil
    )
    mockFamilyService.stubbedCurrentMember = currentMember
  }

  // MARK: - Initialization Tests

  func testInitialState() {
    XCTAssertNil(sut.stats)
    XCTAssertTrue(sut.quickTasks.isEmpty)
    XCTAssertTrue(sut.suggestions.isEmpty)
    XCTAssertTrue(sut.events.isEmpty)
    // Note: activities property removed - now using RecentActivityWidget with ActivityFeedViewModel
    XCTAssertTrue(sut.metrics.isEmpty)
    XCTAssertTrue(sut.interactionTrends.isEmpty)
    XCTAssertFalse(sut.isLoading)
    XCTAssertFalse(sut.isLoggingOut)
    XCTAssertNil(sut.errorMessage)
    XCTAssertNil(sut.logoutErrorMessage)
    XCTAssertNil(sut.lastUpdated)
  }

  func testInitialStateIsEmpty() {
    XCTAssertTrue(sut.isEmpty)
  }

  // MARK: - Computed Properties Tests

  func testUserEmailReturnsEmail() {
    authenticateUser(email: "test@example.com")

    XCTAssertEqual(sut.userEmail, "test@example.com")
  }

  func testUserEmailReturnsUnknownWhenNoUser() {
    XCTAssertEqual(sut.userEmail, "Unknown")
  }

  func testUserFirstNameExtractsFromEmail() {
    authenticateUser(email: "john@example.com")

    XCTAssertEqual(sut.userFirstName, "John")
  }

  func testUserFirstNameReturnsUserWhenNoUser() {
    XCTAssertEqual(sut.userFirstName, "User")
  }

  func testIsEmptyReturnsFalseWithNonZeroStats() {
    sut.stats = DashboardStats(
      coachCount: 1,
      schoolCount: 0,
      interactionCount: 0,
      totalOffers: 0,
      acceptedOffers: 0,
      aTierSchoolCount: 0,
      acceptanceRate: nil
    )

    XCTAssertFalse(sut.isEmpty)
  }

  func testIsEmptyReturnsTrueWithAllZeroStats() {
    sut.stats = DashboardStats(
      coachCount: 0,
      schoolCount: 0,
      interactionCount: 0,
      totalOffers: 0,
      acceptedOffers: 0,
      aTierSchoolCount: 0,
      acceptanceRate: nil
    )

    XCTAssertTrue(sut.isEmpty)
  }

  // MARK: - Token Display Tests

  func testTruncatedSessionTokenShowsPrefix() {
    authenticateUser()
    setSession(accessToken: "abcdefghijklmnopqrstuvwxyz123456")

    let result = sut.truncatedSessionToken
    XCTAssertEqual(result, "abcdefghijklmnopqrst...")
  }

  func testTruncatedSessionTokenShortToken() {
    authenticateUser()
    setSession(accessToken: "short")

    let result = sut.truncatedSessionToken
    XCTAssertEqual(result, "short...")
  }

  func testTruncatedSessionTokenNoSession() {
    XCTAssertEqual(sut.truncatedSessionToken, "No session")
  }

  // MARK: - Fetch Dashboard Data Tests

  func testFetchDashboardDataSuccess() async {
    authenticateUser()
    setupFamilyContext()

    await sut.fetchDashboardData()

    XCTAssertNotNil(sut.stats)
    XCTAssertEqual(sut.stats?.coachCount, 5)
    XCTAssertEqual(sut.stats?.schoolCount, 10)
    XCTAssertNotNil(sut.lastUpdated)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(mockDashboardService.fetchStatsCallCount, 1)
  }

  func testFetchDashboardDataSetsErrorOnFailure() async {
    authenticateUser()
    setupFamilyContext()
    mockDashboardService.shouldThrowFetchStats = true

    await sut.fetchDashboardData()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage?.contains("Failed to load dashboard") ?? false)
    XCTAssertFalse(sut.isLoading)
  }

  func testFetchDashboardDataGuardsUnauthenticated() async {
    await sut.fetchDashboardData()

    XCTAssertEqual(sut.errorMessage, "User not authenticated")
    XCTAssertEqual(mockDashboardService.fetchStatsCallCount, 0)
  }

  func testFetchDashboardDataUsesSelectedAthleteId() async {
    authenticateUser()
    let parent = makeParentMember()
    mockFamilyService.stubbedCurrentMember = parent
    mockFamilyService.stubbedFamilyMembers = [parent, makeAthleteMember()]
    familyManager.selectedAthleteId = "athlete-member-id"

    await sut.fetchDashboardData()

    XCTAssertEqual(mockDashboardService.lastFetchStatsUserId, "athlete-member-id")
    XCTAssertEqual(mockDashboardService.lastFetchStatsFamilyUnitId, "family-unit-1")
  }

  // MARK: - Quick Task CRUD Tests

  func testAddTaskAppendsAndSaves() {
    authenticateUser()

    sut.addTask("Buy groceries")

    XCTAssertEqual(sut.quickTasks.count, 1)
    XCTAssertEqual(sut.quickTasks.first?.text, "Buy groceries")
    XCTAssertFalse(sut.quickTasks.first?.isCompleted ?? true)
    XCTAssertEqual(mockTaskStorage.saveTasksCallCount, 1)
  }

  func testToggleTaskCompletionTogglesState() {
    authenticateUser()
    sut.addTask("Test task")
    let taskId = sut.quickTasks.first!.id

    XCTAssertFalse(sut.quickTasks.first!.isCompleted)

    sut.toggleTaskCompletion(taskId)

    XCTAssertTrue(sut.quickTasks.first!.isCompleted)
  }

  func testDeleteTaskRemovesFromList() {
    authenticateUser()
    sut.addTask("Task 1")
    sut.addTask("Task 2")
    let taskIdToDelete = sut.quickTasks.first!.id

    sut.deleteTask(taskIdToDelete)

    XCTAssertEqual(sut.quickTasks.count, 1)
    XCTAssertEqual(sut.quickTasks.first?.text, "Task 2")
  }

  func testClearCompletedTasksRemovesOnlyCompleted() {
    authenticateUser()
    sut.addTask("Incomplete task")
    sut.addTask("Completed task")
    let completedId = sut.quickTasks.last!.id
    sut.toggleTaskCompletion(completedId)

    sut.clearCompletedTasks()

    XCTAssertEqual(sut.quickTasks.count, 1)
    XCTAssertEqual(sut.quickTasks.first?.text, "Incomplete task")
  }

  func testLoadQuickTasksSetsErrorOnStorageFailure() {
    authenticateUser()
    mockTaskStorage.shouldThrowOnLoad = true

    sut.loadQuickTasks()

    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage?.contains("Failed to load tasks") ?? false)
  }

  // MARK: - Parent Preview Mode Tests

  func testIsParentPreviewModeReflectsFamilyManager() {
    XCTAssertFalse(sut.isParentPreviewMode)

    let parent = makeParentMember()
    familyManager.currentMember = parent
    familyManager.selectedAthleteId = "athlete-id"

    XCTAssertTrue(sut.isParentPreviewMode)
  }

  func testExitParentPreviewClearsSelection() {
    let parent = makeParentMember()
    familyManager.currentMember = parent
    familyManager.selectedAthleteId = "athlete-id"

    sut.exitParentPreview()

    XCTAssertNil(familyManager.selectedAthleteId)
  }

  // MARK: - Suggestions Tests

  func testDismissSuggestionRemovesFromList() async {
    let suggestion1 = makeSuggestion(id: "s1")
    let suggestion2 = makeSuggestion(id: "s2")
    sut.suggestions = [suggestion1, suggestion2]

    await sut.dismissSuggestion("s1")

    XCTAssertEqual(sut.suggestions.count, 1)
    XCTAssertEqual(sut.suggestions.first?.id, "s2")
    XCTAssertEqual(mockDashboardService.dismissSuggestionCallCount, 1)
    XCTAssertEqual(mockDashboardService.lastDismissedSuggestionId, "s1")
  }

  func testDismissSuggestionSetsErrorOnFailure() async {
    let suggestion = makeSuggestion(id: "s1")
    sut.suggestions = [suggestion]
    mockDashboardService.shouldThrowDismissSuggestion = true

    await sut.dismissSuggestion("s1")

    XCTAssertEqual(sut.errorMessage, "Failed to dismiss suggestion")
    XCTAssertEqual(sut.suggestions.count, 1)
  }

  // MARK: - Complete Suggestion Tests

  func testCompleteSuggestionCallsService() async {
    let suggestionId = "test-suggestion-id"

    await sut.completeSuggestion(suggestionId)

    XCTAssertEqual(mockDashboardService.completeSuggestionCallCount, 1)
    XCTAssertEqual(mockDashboardService.lastCompletedSuggestionId, suggestionId)
  }

  func testCompleteSuggestionRemovesSuggestionFromList() async {
    let suggestion = Suggestion(
      id: "test-id",
      title: "Test",
      description: "Description",
      urgency: .high,
      actionUrl: nil,
      location: "dashboard",
      createdAt: "2026-02-01T12:00:00Z"
    )
    sut.suggestions = [suggestion]

    await sut.completeSuggestion(suggestion.id)

    XCTAssertTrue(sut.suggestions.isEmpty)
  }

  func testCompleteSuggestionSetsErrorOnFailure() async {
    mockDashboardService.shouldThrowCompleteSuggestion = true

    await sut.completeSuggestion("any-id")

    XCTAssertEqual(sut.errorMessage, "Failed to complete suggestion")
  }

  // MARK: - Interaction Trends Tests

  func testFetchInteractionTrendsGroupsByDateAndSorts() async {
    authenticateUser()
    mockDashboardService.stubbedInteractions = [
      makeInteraction(id: "i1", date: "2024-01-15T10:00:00Z"),
      makeInteraction(id: "i2", date: "2024-01-15T14:00:00Z"),
      makeInteraction(id: "i3", date: "2024-01-16T09:00:00Z"),
      makeInteraction(id: "i4", date: "2024-01-14T08:00:00Z"),
    ]

    await sut.fetchInteractionTrends()

    XCTAssertEqual(sut.interactionTrends.count, 3)
    XCTAssertEqual(sut.interactionTrends[0].id, "2024-01-14")
    XCTAssertEqual(sut.interactionTrends[0].count, 1)
    XCTAssertEqual(sut.interactionTrends[1].id, "2024-01-15")
    XCTAssertEqual(sut.interactionTrends[1].count, 2)
    XCTAssertEqual(sut.interactionTrends[2].id, "2024-01-16")
    XCTAssertEqual(sut.interactionTrends[2].count, 1)
  }

  // MARK: - Logout Tests

  func testLogoutSuccess() async {
    authenticateUser()

    await sut.logout()

    XCTAssertEqual(mockAuthManager.logoutCallCount, 1)
    XCTAssertFalse(sut.isLoggingOut)
    XCTAssertNil(sut.logoutErrorMessage)
  }

  func testLogoutFailureSetsError() async {
    authenticateUser()
    mockAuthManager.shouldThrowLogoutError = true

    await sut.logout()

    XCTAssertEqual(mockAuthManager.logoutCallCount, 1)
    XCTAssertEqual(sut.logoutErrorMessage, "Failed to log out. Please try again.")
    XCTAssertFalse(sut.isLoggingOut)
  }

  // MARK: - Selected Athlete Name Tests

  func testSelectedAthleteNameReturnsAthleteWhenNone() {
    XCTAssertEqual(sut.selectedAthleteName, "Athlete")
  }

  func testSelectedAthleteNameReturnsFullName() {
    let athlete = makeAthleteMember()
    familyManager.familyMembers = [athlete]
    familyManager.selectedAthleteId = athlete.id

    XCTAssertEqual(sut.selectedAthleteName, "Alex Doe")
  }

  // MARK: - At-a-Glance Computed Properties Tests

  func testSchoolsWithOffersPercentageWhenNoSchools() async {
    // Given: stats with 0 schools
    authenticateUser()
    let stats = DashboardStats(
      coachCount: 5,
      schoolCount: 0,
      interactionCount: 10,
      totalOffers: 2,
      acceptedOffers: 1,
      aTierSchoolCount: 0,
      acceptanceRate: nil
    )
    mockDashboardService.stubbedStats = stats

    // When
    await sut.fetchDashboardData()

    // Then
    XCTAssertEqual(sut.schoolsWithOffersPercentage, "0%")
  }

  func testSchoolsWithOffersPercentageCalculatesCorrectly() async {
    // Given: stats with schools and offers
    authenticateUser()
    setupFamilyContext()
    let stats = DashboardStats(
      coachCount: 5,
      schoolCount: 10,
      interactionCount: 20,
      totalOffers: 3,
      acceptedOffers: 1,
      aTierSchoolCount: 2,
      acceptanceRate: nil
    )
    mockDashboardService.stubbedStats = stats

    // When
    await sut.fetchDashboardData()

    // Then
    let percentage = sut.schoolsWithOffersPercentage
    XCTAssertTrue(percentage.hasSuffix("%"))
    // Should calculate 3/10 = 30%
    XCTAssertEqual(percentage, "30%")
  }

  func testSchoolsWithOffersPercentageWhenNoOffers() async {
    // Given: stats with schools but no offers
    authenticateUser()
    let stats = DashboardStats(
      coachCount: 5,
      schoolCount: 10,
      interactionCount: 20,
      totalOffers: 0,
      acceptedOffers: 0,
      aTierSchoolCount: 2,
      acceptanceRate: nil
    )
    mockDashboardService.stubbedStats = stats

    // When
    await sut.fetchDashboardData()

    // Then
    XCTAssertEqual(sut.schoolsWithOffersPercentage, "0%")
  }

  func testAvgCoachResponsivenessColorLogicGreen() async {
    // Given: stats with data (default 75% responsiveness)
    authenticateUser()
    setupFamilyContext()
    let stats = DashboardStats(
      coachCount: 5,
      schoolCount: 10,
      interactionCount: 20,
      totalOffers: 3,
      acceptedOffers: 1,
      aTierSchoolCount: 2,
      acceptanceRate: nil
    )
    mockDashboardService.stubbedStats = stats

    // When
    await sut.fetchDashboardData()

    // Then: Color should match responsiveness level (>=75% = green)
    let color = sut.avgCoachResponsivenessColor
    XCTAssertEqual(color, .successGreen)
  }

  func testAvgCoachResponsivenessFormattedValue() async {
    // Given: stats with data
    authenticateUser()
    setupFamilyContext()
    let stats = DashboardStats(
      coachCount: 5,
      schoolCount: 10,
      interactionCount: 20,
      totalOffers: 3,
      acceptedOffers: 1,
      aTierSchoolCount: 2,
      acceptanceRate: nil
    )
    mockDashboardService.stubbedStats = stats

    // When
    await sut.fetchDashboardData()

    // Then: Should format as percentage
    XCTAssertEqual(sut.avgCoachResponsivenessFormatted, "75%")
  }

  func testDaysUntilGraduationFormattedWhenNil() async {
    // Given: no stats
    sut.stats = nil

    // Then
    XCTAssertEqual(sut.daysUntilGraduationFormatted, "--")
  }

  func testDaysUntilGraduationFormattedWhenSet() async {
    // Given: stats exist
    authenticateUser()
    let stats = DashboardStats(
      coachCount: 5,
      schoolCount: 10,
      interactionCount: 20,
      totalOffers: 3,
      acceptedOffers: 1,
      aTierSchoolCount: 2,
      acceptanceRate: nil
    )
    mockDashboardService.stubbedStats = stats

    // When
    await sut.fetchDashboardData()

    // Then: should return a number (placeholder is 365)
    let formatted = sut.daysUntilGraduationFormatted
    XCTAssertNotEqual(formatted, "--")
    XCTAssertEqual(formatted, "365")
  }

  func testInteractionsThisMonthFiltersCorrectly() async {
    // Given: activities from different months
    authenticateUser()
    setupFamilyContext()
    let now = Date()
    let calendar = Calendar.current
    let formatter = ISO8601DateFormatter()

    // Activity from this month
    let thisMonth = formatter.string(from: now)

    // Activity from last month
    let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: now)!
    let lastMonth = formatter.string(from: lastMonthDate)

    mockDashboardService.stubbedActivities = [
      Activity(
        id: "a1",
        activityType: "interaction",
        description: "This month",
        timestamp: thisMonth,
        userId: "test-user-id",
        relatedEntityId: nil
      ),
      Activity(
        id: "a2",
        activityType: "interaction",
        description: "This month 2",
        timestamp: thisMonth,
        userId: "test-user-id",
        relatedEntityId: nil
      ),
      Activity(
        id: "a3",
        activityType: "interaction",
        description: "Last month",
        timestamp: lastMonth,
        userId: "test-user-id",
        relatedEntityId: nil
      ),
    ]

    // When
    await sut.fetchDashboardData()

    // Then: should only count activities from this month
    XCTAssertEqual(sut.interactionsThisMonth, 2)
  }
}
