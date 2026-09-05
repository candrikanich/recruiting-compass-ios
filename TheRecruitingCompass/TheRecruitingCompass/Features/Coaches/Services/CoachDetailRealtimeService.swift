import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "CoachDetailRealtimeService"
)

/// Protocol for managing real-time updates on the coach detail page
protocol CoachDetailRealtimeManaging: Sendable {
  func subscribe(
    coachId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws

  func unsubscribe() async
}

/// Subscribes to Supabase Realtime postgres_changes on the `coaches` table
/// so the coach detail page updates live when data changes from another
/// device, session, or family member.
///
/// Filters by coach `id` — only changes to the viewed coach trigger a refetch.
/// Listens for INSERT, UPDATE, and DELETE events.
actor CoachDetailRealtimeService: CoachDetailRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private var channel: RealtimeChannelV2?

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func subscribe(
    coachId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    await unsubscribe()

    logger.info("Subscribing to coach detail updates for coach: \(coachId)")

    let channel = supabaseManager.client
      .realtimeV2
      .channel("coach-detail-\(coachId)")

    _ = channel.onPostgresChange(
      AnyAction.self,
      schema: "public",
      table: "coaches",
      filter: "id=eq.\(coachId)"
    ) { _ in
      Task { @MainActor in
        logger.info("Realtime: coach change detected")
        onChange()
      }
    }

    do {
      try await channel.subscribeWithError()
      self.channel = channel
      logger.info("Subscribed to coach detail channel")
    } catch {
      logger.error("Failed to subscribe to coach detail: \(error.localizedDescription)")
      throw error
    }
  }

  func unsubscribe() async {
    if let channel {
      await channel.unsubscribe()
      self.channel = nil
      logger.info("Unsubscribed from coach detail channel")
    }
  }
}
