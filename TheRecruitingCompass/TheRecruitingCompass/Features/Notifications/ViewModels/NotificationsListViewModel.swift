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
    notifications.count(where: { !$0.isRead })
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
  private let cache: (any CacheManaging)?

  /// Max age for an instant paint. Appear always revalidates (SWR); this TTL
  /// only decides whether a stale list is shown while the network runs.
  private static let notificationsListCacheTTL: TimeInterval = 300

  // MARK: - Initialization

  init(
    notificationsService: (any NotificationsManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) {
    self.notificationsService = notificationsService ?? NotificationsServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.cache = cache
  }

  convenience init(
    notificationService: any NotificationsManaging,
    authManager: any AuthManaging
  ) {
    self.init(notificationsService: notificationService, authManager: authManager)
  }

  /// Invalidates the cached notifications list so the next `fetchNotifications()`
  /// refetches. Call after any local mutation (mark read, delete).
  private func invalidateNotificationsListCache() async {
    guard let userId = authManager.user?.id else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.notifications(userId: userId))
  }

  // MARK: - Methods

  func fetchNotifications() async {
    guard let userId = authManager.user?.id else {
      errorMessage = NotificationServiceError.notAuthenticated.errorDescription
      return
    }

    let cacheKey = ListCacheKeys.notifications(userId: userId)
    let cacheToUse = cache ?? InMemoryCache.shared
    let stale = await cacheToUse.get([AppNotification].self, forKey: cacheKey)

    if let stale {
      notifications = stale
      logger.info("Loaded \(stale.count) notifications from cache; revalidating")
      do {
        let fresh = try await cacheToUse.staleWhileRevalidate(
          [AppNotification].self,
          forKey: cacheKey,
          ttlSeconds: Self.notificationsListCacheTTL,
          fetch: { try await notificationsService.fetchNotifications(userId: userId) }
        )
        notifications = fresh
        errorMessage = nil
        logger.info("Revalidated \(fresh.count) notifications")
      } catch {
        logger.error(
          "Revalidate failed; keeping \(self.notifications.count) cached notifications: \(error.localizedDescription)"
        )
      }
      return
    }

    await ViewModelHelpers.runLoad(
      setLoading: { self.isLoading = $0 },
      setError: { self.errorMessage = $0 },
      userMessage: "Failed to load notifications. Please try again.",
      logger: logger
    ) {
      let fresh = try await cacheToUse.staleWhileRevalidate(
        [AppNotification].self,
        forKey: cacheKey,
        ttlSeconds: Self.notificationsListCacheTTL,
        fetch: { try await notificationsService.fetchNotifications(userId: userId) }
      )
      notifications = fresh
      logger.info("Loaded \(fresh.count) notifications")
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
      await invalidateNotificationsListCache()
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
      await invalidateNotificationsListCache()
    } catch {
      errorMessage = "Failed to mark all as read"
      logger.error("Failed to mark all as read: \(error.localizedDescription)")
    }
  }

  func deleteNotification(id: String) async {
    do {
      try await notificationsService.deleteNotification(id: id)
      notifications.removeAll { $0.id == id }
      await invalidateNotificationsListCache()
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
      await invalidateNotificationsListCache()
    } catch {
      errorMessage = "Failed to delete read notifications"
      logger.error("Failed to delete all read: \(error.localizedDescription)")
    }
  }

  func refresh() async {
    await invalidateNotificationsListCache()
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
