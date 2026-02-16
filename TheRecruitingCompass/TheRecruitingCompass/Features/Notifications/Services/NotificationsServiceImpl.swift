import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "NotificationsService"
)

/// Sendable: Stateless service with no mutable properties
final class NotificationsServiceImpl: NotificationsManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchNotifications(userId: String) async throws -> [AppNotification] {
    logger.info("Fetching notifications for user: \(userId)")

    let notifications: [AppNotification] = try await supabaseManager.client
      .from("notifications")
      .select()
      .eq("user_id", value: userId)
      .order("scheduled_for", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(notifications.count) notifications")
    return notifications
  }

  func markAsRead(id: String) async throws -> AppNotification {
    logger.info("Marking notification as read: \(id)")

    let now = ISO8601DateFormatter().string(from: Date())

    let notification: AppNotification = try await supabaseManager.client
      .from("notifications")
      .update(["read_at": now, "updated_at": now])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Marked notification as read: \(id)")
    return notification
  }

  func markAllAsRead(userId: String) async throws {
    logger.info("Marking all notifications as read for user: \(userId)")

    let now = ISO8601DateFormatter().string(from: Date())

    try await supabaseManager.client
      .from("notifications")
      .update(["read_at": now, "updated_at": now])
      .eq("user_id", value: userId)
      .is("read_at", value: nil)
      .execute()

    logger.info("Marked all notifications as read")
  }

  func deleteNotification(id: String) async throws {
    logger.info("Deleting notification: \(id)")

    try await supabaseManager.client
      .from("notifications")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Deleted notification: \(id)")
  }

  func deleteAllRead(userId: String) async throws {
    logger.info("Deleting all read notifications for user: \(userId)")

    try await supabaseManager.client
      .from("notifications")
      .delete()
      .eq("user_id", value: userId)
      .not("read_at", operator: .is, value: "null")
      .execute()

    logger.info("Deleted all read notifications")
  }
}
