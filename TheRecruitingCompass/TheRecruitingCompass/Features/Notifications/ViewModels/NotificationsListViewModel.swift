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
    didSet { recomputeDerivedState() }
  }
  private(set) var isLoading = false
  var errorMessage: String?

  // MARK: - Filters & Search

  var selectedTypeFilter: NotificationType? {
    didSet { recomputeDerivedState() }
  }
  var searchText: String = "" {
    didSet { recomputeDerivedState() }
  }

  // MARK: - Navigation

  var selectedDestination: NotificationDestination?

  // MARK: - Computed Properties

  /// Cached derived list — recomputed via `recomputeDerivedState()`
  /// whenever `notifications`, `selectedTypeFilter`, or `searchText` change.
  /// Do not compute this inline elsewhere; it would go stale silently.
  private(set) var filteredNotifications: [AppNotification] = []

  /// Stored so TabView's badge observes this Int, not the full `notifications`
  /// array (which would rebuild every tab on each inbox mutation).
  private(set) var unreadCount = 0
  private(set) var hasUnread = false
  private(set) var hasRead = false

  private func recomputeDerivedState() {
    var unread = 0
    var read = false
    for notification in notifications {
      if notification.isRead {
        read = true
      } else {
        unread += 1
      }
    }
    if unreadCount != unread {
      unreadCount = unread
      hasUnread = unread > 0
    }
    if hasRead != read { hasRead = read }

    var result = notifications
    if let filter = selectedTypeFilter {
      result = result.filter { $0.type == filter }
    }
    if !searchText.isEmpty {
      let query = searchText
      result = result.filter {
        $0.title.localizedCaseInsensitiveContains(query) ||
        $0.message.localizedCaseInsensitiveContains(query)
      }
    }
    if filteredNotifications != result {
      filteredNotifications = result
    }
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

  /// Drops the cached list so the next fetch cannot paint stale rows (pull-to-refresh).
  private func invalidateNotificationsListCache() async {
    guard let userId = authManager.user?.id else { return }
    await (cache ?? InMemoryCache.shared).remove(forKey: ListCacheKeys.notifications(userId: userId))
  }

  /// Writes the in-memory list back so the next appear paints local mutations
  /// instantly, then revalidates.
  private func persistNotificationsListCache() async {
    guard let userId = authManager.user?.id else { return }
    await (cache ?? InMemoryCache.shared).set(
      notifications,
      forKey: ListCacheKeys.notifications(userId: userId),
      ttlSeconds: Self.notificationsListCacheTTL
    )
  }

  /// Skips Observation invalidation when the payload is unchanged (SWR often
  /// returns the same rows).
  private func applyNotifications(_ newValue: [AppNotification]) {
    guard notifications != newValue else { return }
    notifications = newValue
  }

  // MARK: - Methods

  func fetchNotifications() async {
    guard let userId = authManager.user?.id else {
      errorMessage = NotificationServiceError.notAuthenticated.errorDescription
      return
    }

    let cacheKey = ListCacheKeys.notifications(userId: userId)
    let cacheToUse = cache ?? InMemoryCache.shared

    // Single get. Paint stale on this actor, then fetch+set (do not call
    // `staleWhileRevalidate` — its `get` would decode/lookup a second time).
    if let stale = await cacheToUse.get([AppNotification].self, forKey: cacheKey) {
      applyNotifications(stale)
      logger.info("Loaded \(stale.count) notifications from cache; revalidating")
    }

    let showLoading = notifications.isEmpty
    if showLoading { isLoading = true }
    defer { if showLoading { isLoading = false } }

    do {
      let fresh = try await notificationsService.fetchNotifications(userId: userId)
      await cacheToUse.set(
        fresh,
        forKey: cacheKey,
        ttlSeconds: Self.notificationsListCacheTTL
      )
      applyNotifications(fresh)
      errorMessage = nil
      logger.info("Loaded \(fresh.count) notifications")
    } catch {
      if notifications.isEmpty {
        errorMessage = "Failed to load notifications. Please try again."
      }
      logger.error(
        "Fetch failed; keeping \(self.notifications.count) cached notifications: \(error.localizedDescription)"
      )
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
      await persistNotificationsListCache()
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
      await persistNotificationsListCache()
    } catch {
      errorMessage = "Failed to mark all as read"
      logger.error("Failed to mark all as read: \(error.localizedDescription)")
    }
  }

  func deleteNotification(id: String) async {
    do {
      try await notificationsService.deleteNotification(id: id)
      notifications.removeAll { $0.id == id }
      await persistNotificationsListCache()
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
      await persistNotificationsListCache()
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
    guard !searchText.isEmpty || selectedTypeFilter != nil else { return }
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
