import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "TasksRealtimeService"
)

/// Protocol for managing real-time updates on the tasks list page
protocol TasksRealtimeManaging: Sendable {
  func subscribe(
    athleteId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws

  func unsubscribe() async
}

/// Subscribes to Supabase Realtime postgres_changes on the `athlete_task` table
/// so the tasks page updates live when task status changes from another
/// device or session.
///
/// Filters by `athlete_id` — only changes to the current athlete's tasks
/// trigger a refetch.
actor TasksRealtimeService: TasksRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private var channel: RealtimeChannelV2?

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func subscribe(
    athleteId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    await unsubscribe()

    logger.info("Subscribing to tasks updates for athlete: \(athleteId)")

    let channel = supabaseManager.client
      .realtimeV2
      .channel("tasks-list-\(athleteId)")

    _ = channel.onPostgresChange(
      AnyAction.self,
      schema: "public",
      table: "athlete_task",
      filter: "athlete_id=eq.\(athleteId)"
    ) { _ in
      Task { @MainActor in
        logger.info("Realtime: task change detected")
        onChange()
      }
    }

    do {
      try await channel.subscribeWithError()
      self.channel = channel
      logger.info("Subscribed to tasks channel")
    } catch {
      logger.error("Failed to subscribe to tasks: \(error.localizedDescription)")
      throw error
    }
  }

  func unsubscribe() async {
    if let channel {
      await channel.unsubscribe()
      self.channel = nil
      logger.info("Unsubscribed from tasks channel")
    }
  }
}
