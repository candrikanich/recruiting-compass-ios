import XCTest
@testable import TheRecruitingCompass

@MainActor
final class NotificationsListViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: NotificationsListViewModel!
  var mockService: MockNotificationsService!
  var mockAuthManager: MockAuthManager!
  var mockCache: InMemoryCache!

  override func setUp() async throws {
    mockService = MockNotificationsService()
    mockAuthManager = MockAuthManager()
    // Fresh instance per test — InMemoryCache.shared would leak state across tests.
    mockCache = InMemoryCache()
    mockAuthManager.user = User(
      id: "user-1",
      email: "athlete@test.com",
      emailConfirmedAt: "2026-01-01T00:00:00Z",
      phone: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: nil
    )
    mockAuthManager.isAuthenticated = true

    viewModel = NotificationsListViewModel(
      notificationsService: mockService,
      authManager: mockAuthManager,
      cache: mockCache
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockAuthManager = nil
    mockCache = nil
  }

  // MARK: - Initial State Tests

  func testInitialState() {
    XCTAssertTrue(viewModel.notifications.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertNil(viewModel.selectedTypeFilter)
    XCTAssertTrue(viewModel.searchText.isEmpty)
    XCTAssertNil(viewModel.selectedDestination)
    XCTAssertEqual(viewModel.unreadCount, 0)
    XCTAssertFalse(viewModel.hasUnread)
    XCTAssertFalse(viewModel.hasRead)
    XCTAssertTrue(viewModel.isEmpty)
    XCTAssertEqual(viewModel.activeFilterCount, 0)
  }

  // MARK: - Fetch Notifications Tests

  func testFetchNotifications_Success_UpdatesState() async {
    // Given
    mockService.mockNotifications = createMockNotifications(count: 5)

    // When
    await viewModel.fetchNotifications()

    // Then
    XCTAssertEqual(viewModel.notifications.count, 5)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isEmpty)
  }

  func testFetchNotifications_Empty_SetsEmptyState() async {
    // Given
    mockService.mockNotifications = []

    // When
    await viewModel.fetchNotifications()

    // Then
    XCTAssertTrue(viewModel.notifications.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.isEmpty)
  }

  func testFetchNotifications_Error_SetsErrorMessage() async {
    // Given
    mockService.shouldSucceed = false

    // When
    await viewModel.fetchNotifications()

    // Then
    XCTAssertTrue(viewModel.notifications.isEmpty)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testFetchNotifications_NoUser_SetsErrorMessage() async {
    // Given
    mockAuthManager.user = nil
    mockService.mockNotifications = createMockNotifications(count: 3)

    // When
    await viewModel.fetchNotifications()

    // Then
    XCTAssertTrue(viewModel.notifications.isEmpty)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testFetchNotifications_PreservesServiceOrder() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "first"),
      makeNotification(id: "second"),
      makeNotification(id: "third")
    ]

    // When
    await viewModel.fetchNotifications()

    // Then
    XCTAssertEqual(viewModel.notifications[0].id, "first")
    XCTAssertEqual(viewModel.notifications[1].id, "second")
    XCTAssertEqual(viewModel.notifications[2].id, "third")
  }

  // MARK: - Unread Count Tests

  func testUnreadCount_AllUnread() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", readAt: nil),
      makeNotification(id: "2", readAt: nil),
      makeNotification(id: "3", readAt: nil)
    ]
    await viewModel.fetchNotifications()

    // Then
    XCTAssertEqual(viewModel.unreadCount, 3)
    XCTAssertTrue(viewModel.hasUnread)
  }

  func testUnreadCount_SomeRead() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", readAt: nil),
      makeNotification(id: "2", readAt: "2026-02-15T10:00:00Z"),
      makeNotification(id: "3", readAt: nil)
    ]
    await viewModel.fetchNotifications()

    // Then
    XCTAssertEqual(viewModel.unreadCount, 2)
    XCTAssertTrue(viewModel.hasUnread)
    XCTAssertTrue(viewModel.hasRead)
  }

  func testUnreadCount_AllRead() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", readAt: "2026-02-15T10:00:00Z"),
      makeNotification(id: "2", readAt: "2026-02-15T11:00:00Z")
    ]
    await viewModel.fetchNotifications()

    // Then
    XCTAssertEqual(viewModel.unreadCount, 0)
    XCTAssertFalse(viewModel.hasUnread)
    XCTAssertTrue(viewModel.hasRead)
  }

  func testUnreadCount_Empty() async {
    // Given
    mockService.mockNotifications = []
    await viewModel.fetchNotifications()

    // Then
    XCTAssertEqual(viewModel.unreadCount, 0)
    XCTAssertFalse(viewModel.hasUnread)
    XCTAssertFalse(viewModel.hasRead)
  }

  // MARK: - Filter by Type Tests

  func testFilteredNotifications_NoFilter_ReturnsAll() async {
    // Given
    mockService.mockNotifications = createMockNotifications(count: 5)
    await viewModel.fetchNotifications()
    viewModel.selectedTypeFilter = nil

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 5)
  }

  func testFilteredNotifications_ByType_FiltersCorrectly() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", type: .followUpReminder),
      makeNotification(id: "2", type: .deadlineAlert),
      makeNotification(id: "3", type: .followUpReminder),
      makeNotification(id: "4", type: .offer)
    ]
    await viewModel.fetchNotifications()

    // When
    viewModel.selectedTypeFilter = .followUpReminder

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 2)
    XCTAssertTrue(viewModel.filteredNotifications.allSatisfy { $0.type == .followUpReminder })
  }

  func testFilteredNotifications_ByType_NoMatches() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", type: .followUpReminder),
      makeNotification(id: "2", type: .deadlineAlert)
    ]
    await viewModel.fetchNotifications()

    // When
    viewModel.selectedTypeFilter = .offer

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 0)
  }

  // MARK: - Search Tests

  func testFilteredNotifications_SearchByTitle() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", title: "Follow up with Coach Smith"),
      makeNotification(id: "2", title: "Deadline approaching for Stanford"),
      makeNotification(id: "3", title: "Follow up with Coach Jones")
    ]
    await viewModel.fetchNotifications()

    // When
    viewModel.searchText = "follow up"

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 2)
  }

  func testFilteredNotifications_SearchByMessage() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", message: "Contact Coach Smith about the camp"),
      makeNotification(id: "2", message: "Your application deadline is tomorrow"),
      makeNotification(id: "3", message: "Coach Jones wants to schedule a camp visit")
    ]
    await viewModel.fetchNotifications()

    // When
    viewModel.searchText = "camp"

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 2)
  }

  func testFilteredNotifications_SearchIsCaseInsensitive() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", title: "FOLLOW UP with coach")
    ]
    await viewModel.fetchNotifications()

    // When
    viewModel.searchText = "follow up"

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 1)
  }

  func testFilteredNotifications_EmptySearch_ReturnsAll() async {
    // Given
    mockService.mockNotifications = createMockNotifications(count: 3)
    await viewModel.fetchNotifications()

    // When
    viewModel.searchText = ""

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 3)
  }

  func testFilteredNotifications_CombinedSearchAndTypeFilter() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", type: .followUpReminder, title: "Follow up with Coach Smith"),
      makeNotification(id: "2", type: .followUpReminder, title: "Follow up with Coach Jones"),
      makeNotification(id: "3", type: .deadlineAlert, title: "Follow up deadline"),
      makeNotification(id: "4", type: .offer, title: "New offer received")
    ]
    await viewModel.fetchNotifications()

    // When
    viewModel.searchText = "follow up"
    viewModel.selectedTypeFilter = .followUpReminder

    // Then
    XCTAssertEqual(viewModel.filteredNotifications.count, 2)
    XCTAssertTrue(viewModel.filteredNotifications.allSatisfy { $0.type == .followUpReminder })
  }

  // MARK: - Cached filteredNotifications Staleness Tests
  // filteredNotifications is a cached stored property (Phase 3.3), recomputed
  // via didSet on notifications/selectedTypeFilter/searchText — not read live.

  func testFilteredNotifications_UpdatesWhenNotificationsReassigned_WithoutTouchingFilter() {
    viewModel.notifications = [makeNotification(id: "1", type: .followUpReminder)]
    viewModel.selectedTypeFilter = .followUpReminder
    XCTAssertEqual(viewModel.filteredNotifications.count, 1)

    viewModel.notifications = [
      makeNotification(id: "2", type: .followUpReminder),
      makeNotification(id: "3", type: .deadlineAlert)
    ]

    XCTAssertEqual(viewModel.filteredNotifications.count, 1)
    XCTAssertEqual(viewModel.filteredNotifications.first?.id, "2")
  }

  func testFilteredNotifications_UpdatesAfterDeleteWithoutExplicitRecompute() async {
    let keep = makeNotification(id: "keep", type: .followUpReminder)
    let remove = makeNotification(id: "remove", type: .followUpReminder)
    viewModel.notifications = [keep, remove]
    viewModel.selectedTypeFilter = .followUpReminder
    XCTAssertEqual(viewModel.filteredNotifications.count, 2)

    await viewModel.deleteNotification(id: "remove")

    XCTAssertEqual(viewModel.filteredNotifications.count, 1)
    XCTAssertEqual(viewModel.filteredNotifications.first?.id, "keep")
  }

  // MARK: - Active Filter Count Tests

  func testActiveFilterCount_NoFilters() {
    XCTAssertEqual(viewModel.activeFilterCount, 0)
  }

  func testActiveFilterCount_SearchOnly() {
    viewModel.searchText = "test"
    XCTAssertEqual(viewModel.activeFilterCount, 1)
  }

  func testActiveFilterCount_TypeOnly() {
    viewModel.selectedTypeFilter = .offer
    XCTAssertEqual(viewModel.activeFilterCount, 1)
  }

  func testActiveFilterCount_Both() {
    viewModel.searchText = "test"
    viewModel.selectedTypeFilter = .deadlineAlert
    XCTAssertEqual(viewModel.activeFilterCount, 2)
  }

  // MARK: - Clear Filters Tests

  func testClearFilters() {
    // Given
    viewModel.searchText = "test search"
    viewModel.selectedTypeFilter = .followUpReminder
    XCTAssertEqual(viewModel.activeFilterCount, 2)

    // When
    viewModel.clearFilters()

    // Then
    XCTAssertTrue(viewModel.searchText.isEmpty)
    XCTAssertNil(viewModel.selectedTypeFilter)
    XCTAssertEqual(viewModel.activeFilterCount, 0)
  }

  // MARK: - List Fetch Caching Tests (Phase 3.6)

  func testFetchNotifications_SecondLoad_UsesCacheAndSkipsService() async {
    mockService.mockNotifications = [makeNotification(id: "1")]

    await viewModel.fetchNotifications()
    XCTAssertEqual(mockService.fetchNotificationsCallCount, 1)

    mockService.mockNotifications = [makeNotification(id: "2")]
    await viewModel.fetchNotifications()

    XCTAssertEqual(mockService.fetchNotificationsCallCount, 1)
    XCTAssertEqual(viewModel.notifications.first?.id, "1")
  }

  func testMarkAsRead_InvalidatesListCache_NextFetchRefetches() async {
    mockService.mockNotifications = [makeNotification(id: "1")]
    await viewModel.fetchNotifications()
    XCTAssertEqual(mockService.fetchNotificationsCallCount, 1)

    await viewModel.markAsRead(id: "1")

    mockService.mockNotifications = []
    await viewModel.fetchNotifications()

    XCTAssertEqual(mockService.fetchNotificationsCallCount, 2)
  }

  func testDeleteNotification_InvalidatesListCache_NextFetchRefetches() async {
    mockService.mockNotifications = [makeNotification(id: "1")]
    await viewModel.fetchNotifications()
    XCTAssertEqual(mockService.fetchNotificationsCallCount, 1)

    await viewModel.deleteNotification(id: "1")

    mockService.mockNotifications = []
    await viewModel.fetchNotifications()

    XCTAssertEqual(mockService.fetchNotificationsCallCount, 2)
  }

  // MARK: - Mark As Read Tests

  func testMarkAsRead_Success_UpdatesLocalState() async {
    // Given
    let unread = makeNotification(id: "1", readAt: nil)
    mockService.mockNotifications = [unread]
    await viewModel.fetchNotifications()

    // When
    await viewModel.markAsRead(id: "1")

    // Then
    XCTAssertEqual(mockService.markAsReadCallCount, 1)
    XCTAssertTrue(viewModel.notifications[0].isRead)
  }

  func testMarkAsRead_Error_SetsErrorMessage() async {
    // Given
    let unread = makeNotification(id: "1", readAt: nil)
    mockService.mockNotifications = [unread]
    await viewModel.fetchNotifications()
    mockService.shouldSucceed = false

    // When
    await viewModel.markAsRead(id: "1")

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testMarkAsRead_AlreadyRead_SkipsServiceCall() async {
    // Given
    let alreadyRead = makeNotification(id: "1", readAt: "2026-02-15T10:00:00Z")
    mockService.mockNotifications = [alreadyRead]
    await viewModel.fetchNotifications()

    // When
    await viewModel.markAsRead(id: "1")

    // Then
    XCTAssertEqual(mockService.markAsReadCallCount, 0)
  }

  // MARK: - Mark All As Read Tests

  func testMarkAllAsRead_Success_UpdatesAll() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", readAt: nil),
      makeNotification(id: "2", readAt: "2026-02-15T10:00:00Z"),
      makeNotification(id: "3", readAt: nil)
    ]
    await viewModel.fetchNotifications()

    // When
    await viewModel.markAllAsRead()

    // Then
    XCTAssertEqual(mockService.markAllAsReadCallCount, 1)
    XCTAssertTrue(viewModel.notifications.allSatisfy { $0.isRead })
    XCTAssertFalse(viewModel.isLoading)
  }

  func testMarkAllAsRead_Error_SetsErrorMessage() async {
    // Given
    mockService.mockNotifications = [makeNotification(id: "1", readAt: nil)]
    await viewModel.fetchNotifications()
    mockService.shouldSucceed = false

    // When
    await viewModel.markAllAsRead()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testMarkAllAsRead_NoUser_DoesNothing() async {
    // Given
    mockAuthManager.user = nil

    // When
    await viewModel.markAllAsRead()

    // Then
    XCTAssertEqual(mockService.markAllAsReadCallCount, 0)
  }

  // MARK: - Delete Notification Tests

  func testDeleteNotification_Success_RemovesFromList() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1"),
      makeNotification(id: "2"),
      makeNotification(id: "3")
    ]
    await viewModel.fetchNotifications()

    // When
    await viewModel.deleteNotification(id: "2")

    // Then
    XCTAssertEqual(viewModel.notifications.count, 2)
    XCTAssertFalse(viewModel.notifications.contains { $0.id == "2" })
    XCTAssertEqual(mockService.deleteCallCount, 1)
  }

  func testDeleteNotification_Error_KeepsNotification() async {
    // Given
    mockService.mockNotifications = [makeNotification(id: "1")]
    await viewModel.fetchNotifications()
    mockService.shouldSucceed = false

    // When
    await viewModel.deleteNotification(id: "1")

    // Then
    XCTAssertEqual(viewModel.notifications.count, 1)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  // MARK: - Delete All Read Tests

  func testDeleteAllRead_Success_RemovesOnlyRead() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", readAt: nil),
      makeNotification(id: "2", readAt: "2026-02-15T10:00:00Z"),
      makeNotification(id: "3", readAt: nil),
      makeNotification(id: "4", readAt: "2026-02-15T11:00:00Z")
    ]
    await viewModel.fetchNotifications()

    // When
    await viewModel.deleteAllRead()

    // Then
    XCTAssertEqual(viewModel.notifications.count, 2)
    XCTAssertTrue(viewModel.notifications.allSatisfy { !$0.isRead })
    XCTAssertEqual(mockService.deleteAllReadCallCount, 1)
  }

  func testDeleteAllRead_Error_KeepsNotifications() async {
    // Given
    mockService.mockNotifications = [
      makeNotification(id: "1", readAt: "2026-02-15T10:00:00Z")
    ]
    await viewModel.fetchNotifications()
    mockService.shouldSucceed = false

    // When
    await viewModel.deleteAllRead()

    // Then
    XCTAssertEqual(viewModel.notifications.count, 1)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testDeleteAllRead_NoUser_DoesNothing() async {
    // Given
    mockAuthManager.user = nil

    // When
    await viewModel.deleteAllRead()

    // Then
    XCTAssertEqual(mockService.deleteAllReadCallCount, 0)
  }

  // MARK: - Handle Notification Tap Tests

  func testHandleNotificationTap_MarksUnreadAndNavigatesToCoach() async {
    // Given
    let notification = makeNotification(
      id: "1",
      readAt: nil,
      relatedEntityType: "coach",
      relatedCoachId: "coach-1"
    )
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertEqual(mockService.markAsReadCallCount, 1)
    XCTAssertEqual(viewModel.selectedDestination, .coachDetail(id: "coach-1"))
  }

  func testHandleNotificationTap_NavigatesToSchool() async {
    // Given
    let notification = makeNotification(
      id: "1",
      readAt: nil,
      relatedEntityType: "school",
      relatedEntityId: "school-1"
    )
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertEqual(viewModel.selectedDestination, .schoolDetail(id: "school-1"))
  }

  func testHandleNotificationTap_NavigatesToOffer() async {
    // Given
    let notification = makeNotification(
      id: "1",
      readAt: nil,
      relatedEntityType: "offer",
      relatedOfferId: "offer-1"
    )
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertEqual(viewModel.selectedDestination, .offerDetail(id: "offer-1"))
  }

  func testHandleNotificationTap_NavigatesToEvent() async {
    // Given
    let notification = makeNotification(
      id: "1",
      readAt: nil,
      relatedEntityType: "event",
      relatedEventId: "event-1"
    )
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertEqual(viewModel.selectedDestination, .eventDetail(id: "event-1"))
  }

  func testHandleNotificationTap_NavigatesToInteraction() async {
    // Given
    let notification = makeNotification(
      id: "1",
      readAt: nil,
      relatedEntityType: "interaction",
      relatedEntityId: "interaction-1"
    )
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertEqual(viewModel.selectedDestination, .interactionDetail(id: "interaction-1"))
  }

  func testHandleNotificationTap_AlreadyRead_SkipsMarkRead_StillNavigates() async {
    // Given
    let notification = makeNotification(
      id: "1",
      readAt: "2026-02-15T10:00:00Z",
      relatedEntityType: "coach",
      relatedCoachId: "coach-1"
    )
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertEqual(mockService.markAsReadCallCount, 0)
    XCTAssertEqual(viewModel.selectedDestination, .coachDetail(id: "coach-1"))
  }

  func testHandleNotificationTap_NoRelatedEntity_NilDestination() async {
    // Given
    let notification = makeNotification(id: "1", readAt: nil)
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertEqual(mockService.markAsReadCallCount, 1)
    XCTAssertNil(viewModel.selectedDestination)
  }

  func testHandleNotificationTap_UnknownEntityType_NilDestination() async {
    // Given
    let notification = makeNotification(
      id: "1",
      readAt: nil,
      relatedEntityType: "unknown",
      relatedEntityId: "some-id"
    )
    mockService.mockNotifications = [notification]
    await viewModel.fetchNotifications()

    // When
    await viewModel.handleNotificationTap(notification)

    // Then
    XCTAssertNil(viewModel.selectedDestination)
  }

  // MARK: - Refresh Tests

  func testRefresh_ReloadsData() async {
    // Given
    mockService.mockNotifications = createMockNotifications(count: 3)

    // When
    await viewModel.refresh()

    // Then
    XCTAssertEqual(viewModel.notifications.count, 3)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testRefresh_ClearsError() async {
    // Given
    mockService.shouldSucceed = false
    await viewModel.fetchNotifications()
    XCTAssertNotNil(viewModel.errorMessage)

    // When
    mockService.shouldSucceed = true
    mockService.mockNotifications = createMockNotifications(count: 2)
    await viewModel.refresh()

    // Then
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.notifications.count, 2)
  }

  // MARK: - markingAsRead Model Method Tests

  func testMarkingAsRead_CreatesReadCopy() {
    // Given
    let notification = makeNotification(id: "1", readAt: nil)
    XCTAssertFalse(notification.isRead)

    // When
    let marked = notification.markingAsRead(at: "2026-02-15T12:00:00Z")

    // Then
    XCTAssertTrue(marked.isRead)
    XCTAssertEqual(marked.readAt, "2026-02-15T12:00:00Z")
    XCTAssertEqual(marked.updatedAt, "2026-02-15T12:00:00Z")
    XCTAssertEqual(marked.id, notification.id)
    XCTAssertEqual(marked.title, notification.title)
  }

  // MARK: - Helper Methods

  private func createMockNotifications(count: Int) -> [AppNotification] {
    (0..<count).map { index in
      makeNotification(id: "\(index)")
    }
  }

  private func makeNotification(
    id: String,
    type: NotificationType = .followUpReminder,
    title: String = "Test Notification",
    message: String = "Test message",
    priority: NotificationPriority = .normal,
    readAt: String? = nil,
    scheduledFor: String = "2026-02-15T10:00:00Z",
    relatedEntityType: String? = nil,
    relatedEntityId: String? = nil,
    relatedSchoolId: String? = nil,
    relatedCoachId: String? = nil,
    relatedOfferId: String? = nil,
    relatedEventId: String? = nil
  ) -> AppNotification {
    AppNotification(
      id: id,
      userId: "user-1",
      type: type,
      title: title,
      message: message,
      priority: priority,
      readAt: readAt,
      scheduledFor: scheduledFor,
      sentAt: nil,
      emailSent: nil,
      emailSentAt: nil,
      actionUrl: nil,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      relatedSchoolId: relatedSchoolId,
      relatedCoachId: relatedCoachId,
      relatedOfferId: relatedOfferId,
      relatedEventId: relatedEventId,
      createdAt: "2026-02-15T09:00:00Z",
      updatedAt: nil
    )
  }
}
