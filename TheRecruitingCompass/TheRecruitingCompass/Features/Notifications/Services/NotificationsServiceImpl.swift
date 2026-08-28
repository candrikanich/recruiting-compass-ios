import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "NotificationsService"
)

/// Sendable: Stateless service with no mutable properties
final class NotificationsServiceImpl: NotificationsManaging, Sendable {
  private static let isoFormatter = ISO8601DateFormatter()
  /// Skip email/push bookkeeping columns the inbox never renders.
  private static let inboxColumns = """
    id, user_id, type, title, message, priority, read_at, scheduled_for, \
    action_url, related_entity_type, related_entity_id, related_school_id, \
    related_coach_id, related_offer_id, related_event_id, created_at
    """
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchNotifications(userId: String) async throws -> [AppNotification] {
    logger.debug("Fetching notifications for user: \(userId, privacy: .private)")
    do {
      let notifications: [AppNotification] = try await supabaseManager.client
        .from("notifications")
        .select(Self.inboxColumns)
        .eq("user_id", value: userId)
        // Inbox clock is `created_at`. `scheduled_for` is null on trigger
        // inserts (offer / inbound / event), so ordering by it surfaces NULLs
        // first under Postgres DESC and hides recency.
        .order("created_at", ascending: false)
        .order("id", ascending: false)
        .execute()
        .value
      logger.info("Fetched \(notifications.count) notifications")
      return notifications
    } catch {
      logger.error("fetchNotifications failed: \(error.localizedDescription)")
      throw error
    }
  }

  func markAsRead(id: String) async throws -> AppNotification {
    logger.debug("Marking notification as read: \(id)")
    do {
      // `notifications` has no `updated_at` column. PostgREST rejects any
      // PATCH that includes it (PGRST204). Web updates `read_at` only.
      let notification: AppNotification = try await supabaseManager.client
        .from("notifications")
        .update(["read_at": Self.isoFormatter.string(from: Date.now)])
        .eq("id", value: id)
        .select()
        .single()
        .execute()
        .value
      logger.info("Marked notification as read: \(id)")
      return notification
    } catch {
      logger.error("markAsRead \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func markAllAsRead(userId: String) async throws {
    logger.debug("Marking all notifications as read for user: \(userId, privacy: .private)")
    do {
      try await supabaseManager.client
        .from("notifications")
        .update(["read_at": Self.isoFormatter.string(from: Date.now)])
        .eq("user_id", value: userId)
        .is("read_at", value: nil)
        .execute()
      logger.info("Marked all notifications as read")
    } catch {
      logger.error("markAllAsRead failed: \(error.localizedDescription)")
      throw error
    }
  }

  func deleteNotification(id: String) async throws {
    logger.debug("Deleting notification: \(id)")
    do {
      try await supabaseManager.client
        .from("notifications")
        .delete()
        .eq("id", value: id)
        .execute()
      logger.info("Deleted notification: \(id)")
    } catch {
      logger.error("deleteNotification \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func deleteAllRead(userId: String) async throws {
    logger.debug("Deleting all read notifications for user: \(userId, privacy: .private)")
    do {
      try await supabaseManager.client
        .from("notifications")
        .delete()
        .eq("user_id", value: userId)
        .not("read_at", operator: .is, value: "null")
        .execute()
      logger.info("Deleted all read notifications")
    } catch {
      logger.error("deleteAllRead failed: \(error.localizedDescription)")
      throw error
    }
  }
}
