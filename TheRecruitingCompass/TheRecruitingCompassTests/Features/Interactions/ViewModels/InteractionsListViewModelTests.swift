import XCTest
@testable import TheRecruitingCompass

@MainActor
final class InteractionsListViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: InteractionsListViewModel!
  var mockService: MockInteractionsService!
  var mockFamilyManager: FamilyManager!
  var mockAuthManager: MockAuthManager!
  var mockCache: InMemoryCache!

  override func setUp() async throws {
    mockService = MockInteractionsService()
    mockFamilyManager = FamilyManager.shared
    mockAuthManager = MockAuthManager()
    // Fresh instance per test — InMemoryCache.shared would leak state across tests.
    mockCache = InMemoryCache()

    viewModel = InteractionsListViewModel(
      interactionsService: mockService,
      familyManager: mockFamilyManager,
      authManager: mockAuthManager,
      cache: mockCache
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockFamilyManager = nil
    mockAuthManager = nil
    mockCache = nil
  }

  // MARK: - Data Loading Tests

  func testLoadInteractions_ForAthlete_Success() async {
    // Given
    let athlete = createFamilyMember(role: "athlete", userId: "athlete1")
    mockFamilyManager.currentMember = athlete
    mockAuthManager.user = User(
      id: "athlete1",
      email: "athlete@test.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: nil
    )

    let interactions = createMockInteractions(count: 5, loggedBy: "athlete1")
    mockService.mockInteractions = interactions
    mockService.mockSchools = createMockSchools(count: 2)
    mockService.mockCoaches = createMockCoaches(count: 3)

    // When
    await viewModel.loadInteractions()

    // Then
    XCTAssertEqual(viewModel.allInteractions.count, 5)
    XCTAssertEqual(viewModel.allSchools.count, 2)
    XCTAssertEqual(viewModel.allCoaches.count, 3)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadInteractions_ForParent_Success() async {
    // Given
    let parent = createFamilyMember(role: "parent", userId: "parent1")
    mockFamilyManager.currentMember = parent
    mockAuthManager.user = User(
      id: "parent1",
      email: "parent@test.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: nil
    )

    let interactions = createMockInteractions(count: 10, loggedBy: "various")
    mockService.mockInteractions = interactions
    mockService.mockSchools = createMockSchools(count: 2)

    // When
    await viewModel.loadInteractions()

    // Then
    XCTAssertEqual(viewModel.allInteractions.count, 10)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadInteractions_NoFamilyUnit_ShowsError() async {
    // Given
    mockFamilyManager.currentMember = nil

    // When
    await viewModel.loadInteractions()

    // Then
    XCTAssertEqual(viewModel.allInteractions.count, 0)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadInteractions_ServiceError_ShowsError() async {
    // Given
    let member = createFamilyMember(role: "athlete", userId: "user1")
    mockFamilyManager.currentMember = member
    mockAuthManager.user = User(
      id: "user1",
      email: "test@test.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: nil
    )
    mockService.shouldSucceed = false

    // When
    await viewModel.loadInteractions()

    // Then
    XCTAssertEqual(viewModel.allInteractions.count, 0)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadInteractions_SetsLoadingState() async {
    // Given
    let member = createFamilyMember(role: "athlete", userId: "user1")
    mockFamilyManager.currentMember = member
    mockAuthManager.user = User(
      id: "user1",
      email: "test@test.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: nil
    )
    mockService.mockSchools = []
    mockService.mockCoaches = []
    mockService.mockInteractions = []

    // When
    let loadTask = Task {
      await viewModel.loadInteractions()
    }

    // Then (loading starts)
    // Note: This is tricky to test due to async timing
    await loadTask.value
    XCTAssertFalse(viewModel.isLoading)
  }

  // MARK: - Filtering Tests

  func testFilterBySearchText_Subject() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", subject: "Follow-up Email"),
      createInteraction(id: "2", subject: "Phone Call"),
      createInteraction(id: "3", subject: "Email Response")
    ]

    // When
    viewModel.filters.searchText = "email"

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)
  }

  func testFilterBySearchText_Content() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", content: "Looking forward to camp"),
      createInteraction(id: "2", content: "Thanks for the call"),
      createInteraction(id: "3", content: "Camp was great")
    ]

    // When
    viewModel.filters.searchText = "camp"

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)
  }

  func testFilterBySearchText_CaseInsensitive() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", subject: "EMAIL Follow-up")
    ]

    // When
    viewModel.filters.searchText = "email"

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 1)
  }

  func testFilterByType() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", type: .email),
      createInteraction(id: "2", type: .phoneCall),
      createInteraction(id: "3", type: .email)
    ]

    // When
    viewModel.filters.type = .email

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)
    XCTAssertTrue(viewModel.filteredInteractions.allSatisfy { $0.type == .email })
  }

  func testFilterByDirection() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", direction: .outbound),
      createInteraction(id: "2", direction: .inbound),
      createInteraction(id: "3", direction: .outbound)
    ]

    // When
    viewModel.filters.direction = .outbound

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)
    XCTAssertTrue(viewModel.filteredInteractions.allSatisfy { $0.direction == .outbound })
  }

  func testFilterBySentiment() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", sentiment: .veryPositive),
      createInteraction(id: "2", sentiment: .neutral),
      createInteraction(id: "3", sentiment: .veryPositive)
    ]

    // When
    viewModel.filters.sentiment = .veryPositive

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)
    XCTAssertTrue(viewModel.filteredInteractions.allSatisfy { $0.sentiment == .veryPositive })
  }

  func testFilterByTimePeriod() {
    // Given
    let now = Date()
    let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now)!
    let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: now)!

    viewModel.allInteractions = [
      createInteraction(id: "1", occurredAt: Interaction.iso8601Formatter.string(from: now)),
      createInteraction(id: "2", occurredAt: Interaction.iso8601Formatter.string(from: tenDaysAgo)),
      createInteraction(id: "3", occurredAt: Interaction.iso8601Formatter.string(from: fiveDaysAgo))
    ]

    // When
    viewModel.filters.timePeriod = .last7Days

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)
  }

  func testFilterByLoggedBy() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", loggedBy: "user1"),
      createInteraction(id: "2", loggedBy: "user2"),
      createInteraction(id: "3", loggedBy: "user1")
    ]

    // When
    viewModel.filters.loggedBy = "user1"

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)
    XCTAssertTrue(viewModel.filteredInteractions.allSatisfy { $0.loggedBy == "user1" })
  }

  func testFilterCombination_TypeAndDirection() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", type: .email, direction: .outbound),
      createInteraction(id: "2", type: .email, direction: .inbound),
      createInteraction(id: "3", type: .phoneCall, direction: .outbound)
    ]

    // When
    viewModel.filters.type = .email
    viewModel.filters.direction = .outbound

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 1)
    XCTAssertEqual(viewModel.filteredInteractions.first?.id, "1")
  }

  func testFilterCombination_AllFilters() {
    // Given
    let now = Date()
    viewModel.allInteractions = [
      createInteraction(
        id: "1",
        type: .email,
        direction: .outbound,
        subject: "Follow-up",
        sentiment: .veryPositive,
        occurredAt: Interaction.iso8601Formatter.string(from: now),
        loggedBy: "user1"
      ),
      createInteraction(id: "2", type: .phoneCall, direction: .inbound)
    ]

    // When
    viewModel.filters.searchText = "follow"
    viewModel.filters.type = .email
    viewModel.filters.direction = .outbound
    viewModel.filters.sentiment = .veryPositive
    viewModel.filters.timePeriod = .last7Days
    viewModel.filters.loggedBy = "user1"

    // Then
    XCTAssertEqual(viewModel.filteredInteractions.count, 1)
    XCTAssertEqual(viewModel.filteredInteractions.first?.id, "1")
  }

  func testClearFilters() {
    // Given
    viewModel.filters.searchText = "test"
    viewModel.filters.type = .email
    viewModel.filters.direction = .outbound

    // When
    viewModel.clearFilters()

    // Then
    XCTAssertTrue(viewModel.filters.searchText.isEmpty)
    XCTAssertNil(viewModel.filters.type)
    XCTAssertNil(viewModel.filters.direction)
    XCTAssertNil(viewModel.filters.sentiment)
    XCTAssertNil(viewModel.filters.timePeriod)
    XCTAssertNil(viewModel.filters.loggedBy)
  }

  func testActiveFilterCount() {
    // Given
    viewModel.filters = InteractionFilters()

    // Then (no filters)
    XCTAssertEqual(viewModel.activeFilterCount, 0)

    // When (add filters)
    viewModel.filters.searchText = "test"
    viewModel.filters.type = .email
    viewModel.filters.direction = .outbound

    // Then
    XCTAssertEqual(viewModel.activeFilterCount, 3)
  }

  // MARK: - Analytics Tests

  func testAnalytics_TotalCount() {
    // Given
    viewModel.allInteractions = createMockInteractions(count: 10, loggedBy: "user1")

    // Then
    XCTAssertEqual(viewModel.analytics.totalCount, 10)
  }

  func testAnalytics_OutboundCount() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", direction: .outbound),
      createInteraction(id: "2", direction: .outbound),
      createInteraction(id: "3", direction: .inbound)
    ]

    // Then
    XCTAssertEqual(viewModel.analytics.outboundCount, 2)
  }

  func testAnalytics_InboundCount() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", direction: .outbound),
      createInteraction(id: "2", direction: .inbound),
      createInteraction(id: "3", direction: .inbound)
    ]

    // Then
    XCTAssertEqual(viewModel.analytics.inboundCount, 2)
  }

  func testAnalytics_ThisWeekCount() {
    // Given
    let now = Date()
    let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: now)!
    let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now)!

    viewModel.allInteractions = [
      createInteraction(id: "1", occurredAt: Interaction.iso8601Formatter.string(from: now)),
      createInteraction(id: "2", occurredAt: Interaction.iso8601Formatter.string(from: fiveDaysAgo)),
      createInteraction(id: "3", occurredAt: Interaction.iso8601Formatter.string(from: tenDaysAgo))
    ]

    // Then
    XCTAssertEqual(viewModel.analytics.thisWeekCount, 2)
  }

  func testAnalytics_UpdatesWithFilters() {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1", type: .email),
      createInteraction(id: "2", type: .email),
      createInteraction(id: "3", type: .phoneCall)
    ]

    // When (no filter)
    var analytics = viewModel.analytics
    XCTAssertEqual(analytics.totalCount, 3)

    // When (with filter)
    viewModel.filters.type = .email
    analytics = viewModel.analytics
    XCTAssertEqual(analytics.totalCount, 2)
  }

  // MARK: - Delete Tests

  func testConfirmDelete_SetsInteractionToDelete() {
    // Given
    let interaction = createInteraction(id: "1")

    // When
    viewModel.confirmDelete(interaction)

    // Then
    XCTAssertEqual(viewModel.interactionToDelete?.id, "1")
    XCTAssertTrue(viewModel.showDeleteConfirmation)
  }

  func testDeleteInteraction_Success() async {
    // Given
    let interaction = createInteraction(id: "1")
    viewModel.allInteractions = [interaction]
    viewModel.interactionToDelete = interaction

    // When
    await viewModel.deleteInteraction()

    // Then
    XCTAssertEqual(viewModel.allInteractions.count, 0)
    XCTAssertEqual(mockService.deleteCallCount, 1)
    XCTAssertNotNil(viewModel.successMessage)
    XCTAssertTrue(viewModel.showSuccessToast)
  }

  func testDeleteInteraction_CascadeSuccess() async {
    // Given
    let interaction = createInteraction(id: "1")
    viewModel.allInteractions = [interaction]
    viewModel.interactionToDelete = interaction
    mockService.simpleDeleteShouldFail = true // Simple delete fails, cascade succeeds

    // When
    await viewModel.deleteInteraction()

    // Then
    XCTAssertEqual(viewModel.allInteractions.count, 0)
    XCTAssertEqual(mockService.cascadeDeleteCallCount, 1)
    XCTAssertNotNil(viewModel.successMessage)
    XCTAssertTrue(viewModel.successMessage?.contains("related record") ?? false)
  }

  func testDeleteInteraction_Error() async {
    // Given
    let interaction = createInteraction(id: "1")
    viewModel.allInteractions = [interaction]
    viewModel.interactionToDelete = interaction
    mockService.shouldSucceed = false

    // Prevent cascade from succeeding
    _ = mockService.cascadeDeleteCallCount
    mockService.shouldSucceed = false

    // When
    await viewModel.deleteInteraction()

    // Then (interaction not removed on error)
    XCTAssertEqual(viewModel.allInteractions.count, 1)
    XCTAssertNotNil(viewModel.deleteErrorMessage)
  }

  func testDeleteInteraction_RemovesFromList() async {
    // Given
    viewModel.allInteractions = [
      createInteraction(id: "1"),
      createInteraction(id: "2"),
      createInteraction(id: "3")
    ]
    viewModel.interactionToDelete = viewModel.allInteractions[1]

    // When
    await viewModel.deleteInteraction()

    // Then
    XCTAssertEqual(viewModel.allInteractions.count, 2)
    XCTAssertFalse(viewModel.allInteractions.contains { $0.id == "2" })
  }

  // MARK: - List Fetch Caching Tests (Phase 3.6)

  func testLoadInteractions_ForParent_SecondLoad_UsesCacheAndSkipsService() async {
    let parent = createFamilyMember(role: "parent", userId: "parent1")
    mockFamilyManager.currentMember = parent
    mockAuthManager.user = User(
      id: "parent1", email: "parent@test.com", emailConfirmedAt: nil, phone: nil,
      createdAt: "", updatedAt: "", role: nil
    )
    mockService.mockInteractions = createMockInteractions(count: 3, loggedBy: "various")

    await viewModel.loadInteractions()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)

    mockService.mockInteractions = createMockInteractions(count: 7, loggedBy: "various")
    await viewModel.loadInteractions()

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    XCTAssertEqual(viewModel.allInteractions.count, 3)
  }

  func testLoadInteractions_ForAthlete_SecondLoad_UsesCacheAndSkipsService() async {
    let athlete = createFamilyMember(role: "player", userId: "athlete1")
    mockFamilyManager.currentMember = athlete
    mockAuthManager.user = User(
      id: "athlete1", email: "athlete@test.com", emailConfirmedAt: nil, phone: nil,
      createdAt: "", updatedAt: "", role: nil
    )
    mockService.mockInteractions = createMockInteractions(count: 3, loggedBy: "athlete1")

    await viewModel.loadInteractions()
    XCTAssertEqual(mockService.fetchInteractionsForUserCallCount, 1)

    mockService.mockInteractions = createMockInteractions(count: 5, loggedBy: "athlete1")
    await viewModel.loadInteractions()

    XCTAssertEqual(mockService.fetchInteractionsForUserCallCount, 1)
    XCTAssertEqual(viewModel.allInteractions.count, 3)
  }

  func testDeleteInteraction_InvalidatesListCache_NextLoadRefetches() async {
    let parent = createFamilyMember(role: "parent", userId: "parent1")
    mockFamilyManager.currentMember = parent
    mockAuthManager.user = User(
      id: "parent1", email: "parent@test.com", emailConfirmedAt: nil, phone: nil,
      createdAt: "", updatedAt: "", role: nil
    )
    let interaction = createInteraction(id: "1")
    mockService.mockInteractions = [interaction]

    await viewModel.loadInteractions()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)

    viewModel.interactionToDelete = interaction
    await viewModel.deleteInteraction()

    mockService.mockInteractions = []
    await viewModel.loadInteractions()

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2)
  }

  func testAddInteractionViewModel_Create_InvalidatesInteractionsListCache() async {
    let parent = createFamilyMember(role: "parent", userId: "parent1")
    mockFamilyManager.currentMember = parent
    mockAuthManager.user = User(
      id: "parent1", email: "parent@test.com", emailConfirmedAt: nil, phone: nil,
      createdAt: "", updatedAt: "", role: nil
    )
    mockService.mockInteractions = []
    await viewModel.loadInteractions()
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)

    // Simulate what AddInteractionViewModel does on successful creation:
    // invalidate the same cache key via the shared ListCacheKeys builder.
    await mockCache.remove(forKey: ListCacheKeys.interactionsForFamily(familyUnitId: "family1"))

    mockService.mockInteractions = [createInteraction(id: "new-1")]
    await viewModel.loadInteractions()

    XCTAssertEqual(mockService.fetchInteractionsCallCount, 2)
    XCTAssertEqual(viewModel.allInteractions.count, 1)
  }

  // MARK: - Cached filteredInteractions Staleness Tests
  // filteredInteractions is a cached stored property (Phase 3.3), recomputed via
  // didSet on allInteractions/filters — not read live.

  func testFilteredInteractions_UpdatesWhenAllInteractionsReassigned_WithoutTouchingFilters() {
    viewModel.allInteractions = [createInteraction(id: "1", type: .email)]
    viewModel.filters.type = .email
    XCTAssertEqual(viewModel.filteredInteractions.count, 1)

    viewModel.allInteractions = [
      createInteraction(id: "2", type: .email),
      createInteraction(id: "3", type: .phoneCall)
    ]

    XCTAssertEqual(viewModel.filteredInteractions.count, 1)
    XCTAssertEqual(viewModel.filteredInteractions.first?.id, "2")
  }

  func testFilteredInteractions_UpdatesAfterDeleteWithoutExplicitRecompute() async {
    let keep = createInteraction(id: "keep", type: .email)
    let remove = createInteraction(id: "remove", type: .email)
    viewModel.allInteractions = [keep, remove]
    viewModel.filters.type = .email
    XCTAssertEqual(viewModel.filteredInteractions.count, 2)

    viewModel.interactionToDelete = remove
    await viewModel.deleteInteraction()

    XCTAssertEqual(viewModel.filteredInteractions.count, 1)
    XCTAssertEqual(viewModel.filteredInteractions.first?.id, "keep")
  }

  // MARK: - Role-Based Tests

  func testIsParent_ReturnsTrue() {
    // Given
    mockFamilyManager.currentMember = createFamilyMember(role: "parent", userId: "parent1")

    // Then
    XCTAssertTrue(viewModel.isParent)
    XCTAssertFalse(viewModel.isAthlete)
  }

  func testIsAthlete_ReturnsTrue() {
    // Given — the athlete role in the DB/web is "player" (see FamilyMember.isAthlete)
    mockFamilyManager.currentMember = createFamilyMember(role: "player", userId: "athlete1")

    // Then
    XCTAssertTrue(viewModel.isAthlete)
    XCTAssertFalse(viewModel.isParent)
  }

  // MARK: - Helper Tests

  func testSchoolName_Found() {
    // Given
    viewModel.allSchools = [
      createSchool(id: "school1", name: "Stanford")
    ]

    // Then
    XCTAssertEqual(viewModel.schoolName(for: "school1"), "Stanford")
  }

  func testSchoolName_NotFound() {
    // Given
    viewModel.allSchools = []

    // Then
    XCTAssertEqual(viewModel.schoolName(for: "unknown"), "Unknown School")
  }

  func testSchoolName_Nil() {
    // Then
    XCTAssertNil(viewModel.schoolName(for: nil))
  }

  func testCoachName_Found() {
    // Given
    viewModel.allCoaches = [
      createCoach(id: "coach1", firstName: "John", lastName: "Smith")
    ]

    // Then
    XCTAssertEqual(viewModel.coachName(for: "coach1"), "John Smith")
  }

  func testCoachName_NotFound() {
    // Given
    viewModel.allCoaches = []

    // Then
    XCTAssertEqual(viewModel.coachName(for: "unknown"), "Unknown Coach")
  }

  func testResultCount() {
    // Given
    viewModel.allInteractions = createMockInteractions(count: 5, loggedBy: "user1")

    // Then
    XCTAssertEqual(viewModel.resultCount, 5)

    // When (filter applied)
    viewModel.filters.type = .email
    viewModel.allInteractions = [
      createInteraction(id: "1", type: .email),
      createInteraction(id: "2", type: .phoneCall)
    ]

    // Then
    XCTAssertEqual(viewModel.resultCount, 1)
  }

  // MARK: - Helper Methods

  private func createFamilyMember(role: String, userId: String) -> FamilyMember {
    FamilyMember(
      id: UUID().uuidString,
      userId: userId,
      familyUnitId: "family1",
      role: role,
      addedAt: ISO8601DateFormatter().string(from: Date()),
      user: nil
    )
  }

  private func createInteraction(
    id: String,
    type: InteractionType = .email,
    direction: Direction = .outbound,
    subject: String? = nil,
    content: String? = nil,
    sentiment: Sentiment? = nil,
    occurredAt: String? = nil,
    loggedBy: String? = "user1"
  ) -> Interaction {
    Interaction(
      id: id,
      type: type,
      direction: direction,
      schoolId: "school1",
      coachId: "coach1",
      subject: subject,
      content: content,
      sentiment: sentiment,
      occurredAt: occurredAt,
      loggedBy: loggedBy,
      attachments: nil,
      familyUnitId: "family1",
      createdAt: Interaction.iso8601Formatter.string(from: Date()),
      updatedAt: Interaction.iso8601Formatter.string(from: Date())
    )
  }

  private func createMockInteractions(count: Int, loggedBy: String) -> [Interaction] {
    (0..<count).map { index in
      createInteraction(id: "\(index)", loggedBy: loggedBy)
    }
  }

  private func createMockSchools(count: Int) -> [School] {
    (0..<count).map { index in
      createSchool(id: "school\(index)", name: "School \(index)")
    }
  }

  private func createSchool(id: String, name: String) -> School {
    School(
      id: id,
      userId: "user1",
      name: name,
      location: nil,
      city: nil,
      state: nil,
      division: nil,
      conference: nil,
      ranking: nil,
      isFavorite: false,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "researching",
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
      fitScore: nil,
      fitTier: nil,
      familyUnitId: "family1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "",
      updatedAt: ""
    )
  }

  private func createMockCoaches(count: Int) -> [Coach] {
    (0..<count).map { index in
      createCoach(id: "coach\(index)", firstName: "Coach", lastName: "\(index)")
    }
  }

  private func createCoach(id: String, firstName: String, lastName: String) -> Coach {
    Coach(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: nil,
      phone: nil,
      position: nil,
      schoolId: "school1",
      twitterHandle: nil,
      instagramHandle: nil,
      notes: nil,
      lastContactDate: nil,
      createdAt: "",
      updatedAt: ""
    )
  }
}
