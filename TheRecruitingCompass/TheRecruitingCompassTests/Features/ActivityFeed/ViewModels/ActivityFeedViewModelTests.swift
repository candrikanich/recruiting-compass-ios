import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ActivityFeedViewModelTests: XCTestCase {
  nonisolated deinit {}
  var sut: ActivityFeedViewModel!
  var mockService: MockActivityFeedService!
  var mockAuthManager: MockAuthManager!

  override func setUp() {
    super.setUp()
    mockService = MockActivityFeedService()
    mockAuthManager = MockAuthManager()
    sut = ActivityFeedViewModel(
      activityService: mockService,
      authManager: mockAuthManager
    )
  }

  override func tearDown() {
    sut = nil
    mockService = nil
    mockAuthManager = nil
    super.tearDown()
  }

  // MARK: - Test Helpers

  private func authenticateUser(id: String = "test-user-id") {
    let user = User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: "2024-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
      role: nil
    )
    mockAuthManager.setMockUser(user)
  }

  private func createInteraction(
    id: String,
    type: InteractionType = .email,
    schoolId: String? = "school-1",
    content: String? = "Test content",
    subject: String? = "Test Subject",
    occurredAt: String? = nil,
    createdAt: String = "2026-02-10T10:00:00.000Z"
  ) -> Interaction {
    Interaction(
      id: id,
      type: type,
      direction: .outbound,
      schoolId: schoolId,
      coachId: nil,
      subject: subject,
      content: content,
      sentiment: nil,
      occurredAt: occurredAt ?? createdAt,
      loggedBy: "test-user-id",
      attachments: nil,
      familyUnitId: "family-1",
      createdAt: createdAt,
      updatedAt: nil
    )
  }

  private func createStatusChange(
    id: String,
    schoolId: String = "school-1",
    newStatus: String = "researching",
    notes: String? = "Test notes",
    changedAt: Date = Date()
  ) -> SchoolStatusHistory {
    SchoolStatusHistory(
      id: id,
      schoolId: schoolId,
      previousStatus: nil,
      newStatus: newStatus,
      changedBy: "test-user-id",
      changedAt: changedAt,
      notes: notes,
      createdAt: changedAt
    )
  }

  private func createDocument(
    id: String,
    title: String = "Test Document",
    type: String? = "pdf",
    createdAt: String = "2026-02-10T10:00:00.000Z"
  ) -> DocumentRecord {
    DocumentRecord(id: id, title: title, type: type, createdAt: createdAt)
  }

  private func setupMockDataForFullLoad() {
    mockService.mockInteractions = [
      createInteraction(id: "i1", createdAt: "2026-02-10T10:00:00.000Z"),
      createInteraction(id: "i2", type: .phoneCall, createdAt: "2026-02-09T08:00:00.000Z")
    ]
    mockService.mockStatusChanges = [
      createStatusChange(
        id: "s1",
        schoolId: "school-2",
        changedAt: Date(timeIntervalSince1970: 1739188800) // 2025-02-10T12:00:00Z
      )
    ]
    mockService.mockDocuments = [
      createDocument(id: "d1", createdAt: "2026-02-08T06:00:00.000Z")
    ]
    mockService.mockSchoolNames = [
      "school-1": "Arizona State",
      "school-2": "UCLA"
    ]
  }

  // MARK: - Initialization Tests

  func testInitialState() {
    XCTAssertTrue(sut.activities.isEmpty)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertNil(sut.selectedType)
    XCTAssertEqual(sut.selectedDateRange, .all)
    XCTAssertEqual(sut.searchQuery, "")
    XCTAssertEqual(sut.currentPage, 1)
    XCTAssertEqual(sut.pageSize, 20)
  }

  func testInitialComputedProperties() {
    XCTAssertTrue(sut.filteredActivities.isEmpty)
    XCTAssertTrue(sut.paginatedActivities.isEmpty)
    XCTAssertEqual(sut.totalPages, 1)
    XCTAssertFalse(sut.hasNextPage)
    XCTAssertFalse(sut.hasPreviousPage)
    XCTAssertTrue(sut.recentActivities.isEmpty)
  }

  // MARK: - Load Activities Tests

  func testLoadActivities_Success() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()

    // When
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.activities.count, 4) // 2 interactions + 1 status + 1 document
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 1)
    XCTAssertEqual(mockService.fetchStatusChangesCallCount, 1)
    XCTAssertEqual(mockService.fetchDocumentsCallCount, 1)
    XCTAssertEqual(mockService.fetchSchoolNamesCallCount, 1)
  }

  func testLoadActivities_PassesCorrectUserId() async {
    // Given
    authenticateUser(id: "specific-user")
    mockService.mockSchoolNames = [:]

    // When
    await sut.loadActivities()

    // Then
    XCTAssertEqual(mockService.lastFetchInteractionsUserId, "specific-user")
    XCTAssertEqual(mockService.lastFetchStatusChangesUserId, "specific-user")
    XCTAssertEqual(mockService.lastFetchDocumentsUserId, "specific-user")
  }

  func testLoadActivities_NoUser_SetsError() async {
    // Given: no authenticated user

    // When
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.errorMessage, "Unable to load activities. Please sign in.")
    XCTAssertTrue(sut.activities.isEmpty)
    XCTAssertEqual(mockService.fetchInteractionsCallCount, 0)
  }

  func testLoadActivities_ServiceError_SetsErrorMessage() async {
    // Given
    authenticateUser()
    mockService.shouldThrowOnInteractions = true

    // When
    await sut.loadActivities()

    // Then
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.errorMessage?.contains("Failed to load activities") ?? false)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadActivities_SortsByTimestampDescending() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "old", createdAt: "2026-01-01T00:00:00.000Z"),
      createInteraction(id: "new", createdAt: "2026-02-15T00:00:00.000Z")
    ]
    mockService.mockSchoolNames = ["school-1": "Test School"]

    // When
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.activities.first?.id, "interaction-new")
    XCTAssertEqual(sut.activities.last?.id, "interaction-old")
  }

  func testLoadActivities_HydratesSchoolNames() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", schoolId: "school-abc")
    ]
    mockService.mockSchoolNames = ["school-abc": "Stanford University"]

    // When
    await sut.loadActivities()

    // Then
    XCTAssertTrue(sut.activities.first?.title.contains("Stanford University") ?? false)
    XCTAssertEqual(sut.activities.first?.entityName, "Stanford University")
  }

  func testLoadActivities_MissingSchoolName_ShowsUnknownSchool() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", schoolId: "missing-school")
    ]
    mockService.mockSchoolNames = [:]

    // When
    await sut.loadActivities()

    // Then
    XCTAssertTrue(sut.activities.first?.title.contains("Unknown School") ?? false)
  }

  func testLoadActivities_ResetsPageToOne() async {
    // Given
    authenticateUser()
    sut.currentPage = 3
    mockService.mockSchoolNames = [:]

    // When
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  func testLoadActivities_EmptyResults() async {
    // Given
    authenticateUser()
    mockService.mockSchoolNames = [:]

    // When
    await sut.loadActivities()

    // Then
    XCTAssertTrue(sut.activities.isEmpty)
    XCTAssertNil(sut.errorMessage)
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadActivities_CollectsUniqueSchoolIds() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", schoolId: "school-1"),
      createInteraction(id: "i2", schoolId: "school-1"), // duplicate
      createInteraction(id: "i3", schoolId: "school-2")
    ]
    mockService.mockStatusChanges = [
      createStatusChange(id: "s1", schoolId: "school-2"), // duplicate across sources
      createStatusChange(id: "s2", schoolId: "school-3")
    ]
    mockService.mockSchoolNames = [
      "school-1": "ASU",
      "school-2": "UCLA",
      "school-3": "Stanford"
    ]

    // When
    await sut.loadActivities()

    // Then: should deduplicate school IDs
    let requestedIds = Set(mockService.lastFetchSchoolNamesIds ?? [])
    XCTAssertEqual(requestedIds.count, 3)
    XCTAssertTrue(requestedIds.contains("school-1"))
    XCTAssertTrue(requestedIds.contains("school-2"))
    XCTAssertTrue(requestedIds.contains("school-3"))
  }

  func testLoadActivities_InteractionsWithNilSchoolId_Excluded() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", schoolId: nil)
    ]
    mockService.mockSchoolNames = [:]

    // When
    await sut.loadActivities()

    // Then: nil school IDs should not be sent for hydration
    let requestedIds = mockService.lastFetchSchoolNamesIds ?? []
    XCTAssertTrue(requestedIds.isEmpty)
  }

  // MARK: - Type Filter Tests

  func testFilterByType_Interaction() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()

    // When
    sut.selectedType = .interaction

    // Then
    XCTAssertTrue(sut.filteredActivities.allSatisfy { $0.type == .interaction })
    XCTAssertEqual(sut.filteredActivities.count, 2)
  }

  func testFilterByType_SchoolStatusChange() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()

    // When
    sut.selectedType = .schoolStatusChange

    // Then
    XCTAssertTrue(sut.filteredActivities.allSatisfy { $0.type == .schoolStatusChange })
    XCTAssertEqual(sut.filteredActivities.count, 1)
  }

  func testFilterByType_DocumentUpload() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()

    // When
    sut.selectedType = .documentUpload

    // Then
    XCTAssertTrue(sut.filteredActivities.allSatisfy { $0.type == .documentUpload })
    XCTAssertEqual(sut.filteredActivities.count, 1)
  }

  func testFilterByType_AllReturnsEverything() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()

    // When
    sut.selectedType = nil

    // Then
    XCTAssertEqual(sut.filteredActivities.count, sut.activities.count)
  }

  func testFilterByType_ResetsPage() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.currentPage = 3

    // When
    sut.selectedType = .interaction

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  // MARK: - Date Range Filter Tests

  func testFilterByDateRange_Week() async {
    // Given
    authenticateUser()
    let now = Date()
    let recentDate = now.addingTimeInterval(-3 * 86400) // 3 days ago
    let oldDate = now.addingTimeInterval(-14 * 86400) // 14 days ago

    mockService.mockStatusChanges = [
      createStatusChange(id: "recent", changedAt: recentDate),
      createStatusChange(id: "old", changedAt: oldDate)
    ]
    mockService.mockSchoolNames = ["school-1": "Test School"]
    await sut.loadActivities()

    // When
    sut.selectedDateRange = .week

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 1)
    XCTAssertEqual(sut.filteredActivities.first?.id, "status-recent")
  }

  func testFilterByDateRange_Month() async {
    // Given
    authenticateUser()
    let now = Date()
    let withinMonth = now.addingTimeInterval(-20 * 86400) // 20 days ago
    let outsideMonth = now.addingTimeInterval(-60 * 86400) // 60 days ago

    mockService.mockStatusChanges = [
      createStatusChange(id: "within", changedAt: withinMonth),
      createStatusChange(id: "outside", changedAt: outsideMonth)
    ]
    mockService.mockSchoolNames = ["school-1": "Test School"]
    await sut.loadActivities()

    // When
    sut.selectedDateRange = .month

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 1)
    XCTAssertEqual(sut.filteredActivities.first?.id, "status-within")
  }

  func testFilterByDateRange_Quarter() async {
    // Given
    authenticateUser()
    let now = Date()
    let withinQuarter = now.addingTimeInterval(-60 * 86400) // 60 days ago
    let outsideQuarter = now.addingTimeInterval(-120 * 86400) // 120 days ago

    mockService.mockStatusChanges = [
      createStatusChange(id: "within", changedAt: withinQuarter),
      createStatusChange(id: "outside", changedAt: outsideQuarter)
    ]
    mockService.mockSchoolNames = ["school-1": "Test School"]
    await sut.loadActivities()

    // When
    sut.selectedDateRange = .quarter

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 1)
    XCTAssertEqual(sut.filteredActivities.first?.id, "status-within")
  }

  func testFilterByDateRange_All() async {
    // Given
    authenticateUser()
    let now = Date()
    let recentDate = now.addingTimeInterval(-1 * 86400)
    let oldDate = now.addingTimeInterval(-365 * 86400) // 1 year ago

    mockService.mockStatusChanges = [
      createStatusChange(id: "recent", changedAt: recentDate),
      createStatusChange(id: "old", changedAt: oldDate)
    ]
    mockService.mockSchoolNames = ["school-1": "Test School"]
    await sut.loadActivities()

    // When
    sut.selectedDateRange = .all

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 2)
  }

  func testFilterByDateRange_ResetsPage() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.currentPage = 2

    // When
    sut.selectedDateRange = .week

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  // MARK: - Search Filter Tests

  func testSearchByTitle() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", type: .email),
      createInteraction(id: "i2", type: .phoneCall)
    ]
    mockService.mockSchoolNames = ["school-1": "Arizona State"]
    await sut.loadActivities()

    // When
    sut.searchQuery = "Email"

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 1)
    XCTAssertTrue(sut.filteredActivities.first?.title.contains("Email") ?? false)
  }

  func testSearchByDescription() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", content: "Discussed camp schedule"),
      createInteraction(id: "i2", content: "Roster information")
    ]
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // When
    sut.searchQuery = "camp"

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 1)
    XCTAssertTrue(sut.filteredActivities.first?.description.contains("camp") ?? false)
  }

  func testSearchIsCaseInsensitive() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", content: "EMAIL discussion")
    ]
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // When
    sut.searchQuery = "email"

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 1)
  }

  func testSearchEmpty_ReturnsAll() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()

    // When
    sut.searchQuery = ""

    // Then
    XCTAssertEqual(sut.filteredActivities.count, sut.activities.count)
  }

  func testSearchNoResults() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()

    // When
    sut.searchQuery = "nonexistent query xyz"

    // Then
    XCTAssertTrue(sut.filteredActivities.isEmpty)
  }

  func testSearch_ResetsPage() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.currentPage = 2

    // When
    sut.searchQuery = "test"

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  // MARK: - Cached filteredActivities Staleness Tests
  // filteredActivities is a cached stored property (Phase 3.3), recomputed via
  // didSet on activities/selectedType/selectedDateRange/searchQuery — not read live.

  func testFilteredActivities_UpdatesWhenActivitiesReloaded_WithoutTouchingFilter() async {
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.selectedType = .interaction
    XCTAssertEqual(sut.filteredActivities.count, 2)

    // Reload with entirely different data — a new interaction plus no other types —
    // without touching selectedType again.
    mockService.mockInteractions = [createInteraction(id: "i3")]
    mockService.mockStatusChanges = []
    mockService.mockDocuments = []
    await sut.loadActivities()

    XCTAssertEqual(sut.filteredActivities.count, 1)
    XCTAssertTrue(sut.filteredActivities.allSatisfy { $0.type == .interaction })
  }

  func testFilteredActivities_UpdatesAfterRealtimeInsertWithoutExplicitRecompute() async {
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.selectedType = .interaction
    XCTAssertEqual(sut.filteredActivities.count, 2)

    let newEvent = ActivityEventFactory.fromInteraction(
      createInteraction(id: "realtime-1"),
      schoolName: nil
    )
    sut.addRealtimeEvent(newEvent)

    XCTAssertEqual(sut.filteredActivities.count, 3)
  }

  // MARK: - Combined Filters Tests

  func testCombinedFilters_TypeAndSearch() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", type: .email, content: "Camp info"),
      createInteraction(id: "i2", type: .phoneCall, content: "Camp info")
    ]
    mockService.mockDocuments = [
      createDocument(id: "d1", title: "Camp Schedule")
    ]
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // When: filter by interaction type AND search for "Camp"
    sut.selectedType = .interaction
    sut.searchQuery = "Camp"

    // Then: only interactions containing "Camp"
    XCTAssertEqual(sut.filteredActivities.count, 2)
    XCTAssertTrue(sut.filteredActivities.allSatisfy { $0.type == .interaction })
  }

  func testCombinedFilters_TypeAndDateRange() async {
    // Given
    authenticateUser()
    let now = Date()
    let recentDate = now.addingTimeInterval(-3 * 86400) // 3 days ago
    let oldDate = now.addingTimeInterval(-14 * 86400) // 14 days ago

    mockService.mockStatusChanges = [
      createStatusChange(id: "recent", changedAt: recentDate),
      createStatusChange(id: "old", changedAt: oldDate)
    ]
    mockService.mockInteractions = [
      createInteraction(id: "i1")
    ]
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // When
    sut.selectedType = .schoolStatusChange
    sut.selectedDateRange = .week

    // Then
    XCTAssertEqual(sut.filteredActivities.count, 1)
    XCTAssertEqual(sut.filteredActivities.first?.id, "status-recent")
  }

  // MARK: - Pagination Tests

  func testPaginatedActivities_FirstPage() async {
    // Given: more than 20 items
    authenticateUser()
    let now = Date()
    mockService.mockStatusChanges = (0..<25).map { i in
      createStatusChange(
        id: "s\(i)",
        changedAt: now.addingTimeInterval(Double(-i * 3600))
      )
    }
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.paginatedActivities.count, 20)
    XCTAssertEqual(sut.totalPages, 2)
    XCTAssertTrue(sut.hasNextPage)
    XCTAssertFalse(sut.hasPreviousPage)
  }

  func testPaginatedActivities_SecondPage() async {
    // Given
    authenticateUser()
    let now = Date()
    mockService.mockStatusChanges = (0..<25).map { i in
      createStatusChange(
        id: "s\(i)",
        changedAt: now.addingTimeInterval(Double(-i * 3600))
      )
    }
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // When
    sut.nextPage()

    // Then
    XCTAssertEqual(sut.currentPage, 2)
    XCTAssertEqual(sut.paginatedActivities.count, 5)
    XCTAssertFalse(sut.hasNextPage)
    XCTAssertTrue(sut.hasPreviousPage)
  }

  func testNextPage_DoesNothingOnLastPage() async {
    // Given
    authenticateUser()
    mockService.mockSchoolNames = [:]
    await sut.loadActivities()

    // When
    sut.nextPage()

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  func testPreviousPage_DoesNothingOnFirstPage() {
    // When
    sut.previousPage()

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  func testPreviousPage_GoesBackOnePage() async {
    // Given
    authenticateUser()
    let now = Date()
    mockService.mockStatusChanges = (0..<25).map { i in
      createStatusChange(
        id: "s\(i)",
        changedAt: now.addingTimeInterval(Double(-i * 3600))
      )
    }
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()
    sut.nextPage()
    XCTAssertEqual(sut.currentPage, 2)

    // When
    sut.previousPage()

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  func testTotalPages_ExactlyOnePageOfItems() async {
    // Given
    authenticateUser()
    let now = Date()
    mockService.mockStatusChanges = (0..<20).map { i in
      createStatusChange(
        id: "s\(i)",
        changedAt: now.addingTimeInterval(Double(-i * 3600))
      )
    }
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.totalPages, 1)
    XCTAssertFalse(sut.hasNextPage)
  }

  func testTotalPages_EmptyActivities() {
    XCTAssertEqual(sut.totalPages, 1)
  }

  func testPaginatedActivities_OutOfRange() async {
    // Given
    authenticateUser()
    mockService.mockSchoolNames = [:]
    await sut.loadActivities()
    sut.currentPage = 100

    // Then
    XCTAssertTrue(sut.paginatedActivities.isEmpty)
  }

  // MARK: - Recent Activities Tests

  func testRecentActivities_ReturnsFirst5() async {
    // Given
    authenticateUser()
    let now = Date()
    mockService.mockStatusChanges = (0..<15).map { i in
      createStatusChange(
        id: "s\(i)",
        changedAt: now.addingTimeInterval(Double(-i * 3600))
      )
    }
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.recentActivities.count, 5)
  }

  func testRecentActivities_ReturnsAllWhenFewerThan5() async {
    // Given
    authenticateUser()
    mockService.mockStatusChanges = [
      createStatusChange(id: "s1"),
      createStatusChange(id: "s2")
    ]
    mockService.mockSchoolNames = ["school-1": "Test"]
    await sut.loadActivities()

    // Then
    XCTAssertEqual(sut.recentActivities.count, 2)
  }

  func testRecentActivities_EmptyWhenNoActivities() {
    XCTAssertTrue(sut.recentActivities.isEmpty)
  }

  // MARK: - Clear Filters Tests

  func testClearFilters_ResetsAllFilters() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.selectedType = .interaction
    sut.selectedDateRange = .week
    sut.searchQuery = "test"

    // When
    sut.clearFilters()

    // Then
    XCTAssertNil(sut.selectedType)
    XCTAssertEqual(sut.selectedDateRange, .all)
    XCTAssertEqual(sut.searchQuery, "")
  }

  func testClearFilters_ShowsAllActivities() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    let totalActivities = sut.activities.count
    sut.selectedType = .interaction

    XCTAssertNotEqual(sut.filteredActivities.count, totalActivities)

    // When
    sut.clearFilters()

    // Then
    XCTAssertEqual(sut.filteredActivities.count, totalActivities)
  }

  // MARK: - Loading State Tests

  func testLoadingState_SetsDuringLoad() async {
    // Given
    authenticateUser()
    mockService.mockSchoolNames = [:]

    // When/Then: just verify isLoading is false after completion
    await sut.loadActivities()
    XCTAssertFalse(sut.isLoading)
  }

  func testLoadingState_FalseAfterError() async {
    // Given
    authenticateUser()
    mockService.shouldThrowOnInteractions = true

    // When
    await sut.loadActivities()

    // Then
    XCTAssertFalse(sut.isLoading)
    XCTAssertNotNil(sut.errorMessage)
  }

  // MARK: - Error State Tests

  func testError_ClearedOnNewLoad() async {
    // Given
    authenticateUser()
    mockService.shouldThrowOnInteractions = true
    await sut.loadActivities()
    XCTAssertNotNil(sut.errorMessage)

    // When: retry with success
    mockService.shouldThrowOnInteractions = false
    mockService.mockSchoolNames = [:]
    await sut.loadActivities()

    // Then
    XCTAssertNil(sut.errorMessage)
  }

  func testError_SchoolNamesFetchFails() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [createInteraction(id: "i1")]
    mockService.shouldThrowOnSchoolNames = true

    // When
    await sut.loadActivities()

    // Then
    XCTAssertNotNil(sut.errorMessage)
    XCTAssertTrue(sut.activities.isEmpty)
  }

  // MARK: - Mixed Activity Types Tests

  func testMixedTypes_AllIncluded() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()

    // When
    await sut.loadActivities()

    // Then
    let types = Set(sut.activities.map(\.type))
    XCTAssertTrue(types.contains(.interaction))
    XCTAssertTrue(types.contains(.schoolStatusChange))
    XCTAssertTrue(types.contains(.documentUpload))
  }

  func testMixedTypes_InteractionsTransformed() async {
    // Given
    authenticateUser()
    mockService.mockInteractions = [
      createInteraction(id: "i1", type: .email)
    ]
    mockService.mockSchoolNames = ["school-1": "Test School"]

    // When
    await sut.loadActivities()

    // Then
    let event = sut.activities.first
    XCTAssertEqual(event?.id, "interaction-i1")
    XCTAssertEqual(event?.type, .interaction)
    XCTAssertTrue(event?.isClickable ?? false)
  }

  func testMixedTypes_DocumentsNotClickable() async {
    // Given
    authenticateUser()
    mockService.mockDocuments = [createDocument(id: "d1")]
    mockService.mockSchoolNames = [:]

    // When
    await sut.loadActivities()

    // Then
    let event = sut.activities.first
    XCTAssertEqual(event?.id, "doc-d1")
    XCTAssertEqual(event?.type, .documentUpload)
    XCTAssertFalse(event?.isClickable ?? true)
    XCTAssertNil(event?.clickUrl)
  }

  // MARK: - Page Reset on Filter Change Tests

  func testFilterChangeResetsPage_Type() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.currentPage = 5

    // When
    sut.selectedType = .interaction

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  func testFilterChangeResetsPage_DateRange() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.currentPage = 5

    // When
    sut.selectedDateRange = .week

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  func testFilterChangeResetsPage_Search() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.currentPage = 5

    // When
    sut.searchQuery = "test"

    // Then
    XCTAssertEqual(sut.currentPage, 1)
  }

  func testSameFilterValue_DoesNotResetPage() async {
    // Given
    authenticateUser()
    setupMockDataForFullLoad()
    await sut.loadActivities()
    sut.selectedType = .interaction
    sut.currentPage = 3

    // When: set same value again
    sut.selectedType = .interaction

    // Then: page should NOT reset (didSet checks oldValue)
    XCTAssertEqual(sut.currentPage, 3)
  }

  // MARK: - Athlete Targeting Tests

  func testLoadActivities_parentViewingAthlete_usesAthleteUserId() async {
    // Given
    let familyManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: mockAuthManager)
    sut = ActivityFeedViewModel(
      activityService: mockService,
      familyManager: familyManager,
      authManager: mockAuthManager
    )

    // When
    await sut.loadActivities()

    // Then
    XCTAssertEqual(mockService.lastFetchInteractionsUserId, ParentViewingAthleteFixture.athleteUserId)
    XCTAssertEqual(mockService.lastFetchStatusChangesUserId, ParentViewingAthleteFixture.athleteUserId)
    XCTAssertEqual(mockService.lastFetchDocumentsUserId, ParentViewingAthleteFixture.athleteUserId)
  }
}
