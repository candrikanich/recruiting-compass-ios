import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "NotificationsListViewModel"
)

@Observable
@MainActor
final class NotificationsListViewModel {

  nonisolated deinit {}
  private static let isoFormatter = ISO8601DateFormatter()
  // MARK: - State

  var notifications: [AppNotification] = [] {
    didSet { recomputeFilteredNotifications() }
  }
  private(set) var isLoading = false
  var errorMessage: String?

  // MARK: - Filters & Search

  var selectedTypeFilter: NotificationType? {
    didSet { recomputeFilteredNotifications() }
  }
  var searchText: String = "" {
    didSet { recomputeFilteredNotifications() }
  }

  // MARK: - Navigation

  var selectedDestination: NotificationDestination?

  // MARK: - Computed Properties

  /// Cached derived list — recomputed via `recomputeFilteredNotifications()`
  /// whenever `notifications`, `selectedTypeFilter`, or `searchText` change.
  /// Do not compute this inline elsewhere; it would go stale silently.
  private(set) var filteredNotifications: [AppNotification] = []

  private func recomputeFilteredNotifications() {
    var result = notifications

    if let filter = selectedTypeFilter {
      result = result.filter { $0.type == filter }
    }

    if !searchText.isEmpty {
      let query = searchText
      result = result.filter {
        $0.title.localizedStandardContains(query) ||
        $0.message.localizedStandardContains(query)
      }
    }

    filteredNotifications = result
  }

  var unreadCount: Int {
    notifications.filter { !$0.isRead }.count
  }

  var hasUnread: Bool {
    unreadCount > 0
  }

  var hasRead: Bool {
    notifications.contains { $0.isRead }
  }

  var isEmpty: Bool {
    notifications.isEmpty
  }

  var activeFilterCount: Int {
    var count = 0
    if selectedTypeFilter != nil { count += 1 }
    if !searchText.isEmpty { count += 1 }
    return count
  }

  // MARK: - Dependencies

  private let notificationsService: any NotificationsManaging
  private let authManager: any AuthManaging

  // MARK: - Initialization

  init(
    notificationsService: (any NotificationsManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.notificationsService = notificationsService ?? NotificationsServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  convenience init(
    notificationService: any NotificationsManaging,
    authManager: any AuthManaging
  ) {
    self.init(notificationsService: notificationService, authManager: authManager)
  }

  // MARK: - Methods

  func fetchNotifications() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      guard let userId = authManager.user?.id else {
        throw NotificationServiceError.notAuthenticated
      }

      let fetched = try await notificationsService.fetchNotifications(userId: userId)
      notifications = fetched
      logger.info("Loaded \(fetched.count) notifications")
    } catch {
      errorMessage = "Failed to load notifications. Please try again."
      logger.error("Failed to fetch notifications: \(error.localizedDescription)")
    }
  }

  func markAsRead(id: String) async {
    guard let index = notifications.firstIndex(where: { $0.id == id }),
          !notifications[index].isRead else {
      return
    }

    do {
      let updated = try await notificationsService.markAsRead(id: id)
      if let index = notifications.firstIndex(where: { $0.id == id }) {
        notifications[index] = updated
      }
    } catch {
      errorMessage = "Failed to mark notification as read"
      logger.error("Failed to mark as read: \(error.localizedDescription)")
    }
  }

  func markAllAsRead() async {
    guard let userId = authManager.user?.id else { return }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await notificationsService.markAllAsRead(userId: userId)

      let now = Self.isoFormatter.string(from: Date.now)
      notifications = notifications.map { notification in
        notification.isRead ? notification : notification.markingAsRead(at: now)
      }
    } catch {
      errorMessage = "Failed to mark all as read"
      logger.error("Failed to mark all as read: \(error.localizedDescription)")
    }
  }

  func deleteNotification(id: String) async {
    do {
      try await notificationsService.deleteNotification(id: id)
      notifications.removeAll { $0.id == id }
    } catch {
      errorMessage = "Failed to delete notification"
      logger.error("Failed to delete notification: \(error.localizedDescription)")
    }
  }

  func deleteAllRead() async {
    guard let userId = authManager.user?.id else { return }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await notificationsService.deleteAllRead(userId: userId)
      notifications.removeAll { $0.isRead }
    } catch {
      errorMessage = "Failed to delete read notifications"
      logger.error("Failed to delete all read: \(error.localizedDescription)")
    }
  }

  func refresh() async {
    await fetchNotifications()
  }

  func clearFilters() {
    searchText = ""
    selectedTypeFilter = nil
  }

  func handleNotificationTap(_ notification: AppNotification) async {
    if !notification.isRead {
      await markAsRead(id: notification.id)
    }

    selectedDestination = parseDestination(from: notification)
  }

  // MARK: - Navigation Parsing

  private func parseDestination(from notification: AppNotification) -> NotificationDestination? {
    NotificationDestinationParser.destination(from: notification)
  }
}
