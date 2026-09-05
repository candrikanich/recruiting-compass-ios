import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SchoolDetailRealtimeService"
)

/// Protocol for managing real-time updates on the school detail page
protocol SchoolDetailRealtimeManaging: Sendable {
  func subscribe(
    schoolId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws

  func unsubscribe() async
}

/// Subscribes to Supabase Realtime postgres_changes on the `schools` table
/// so the school detail page updates live when data changes from another
/// device, session, or family member.
///
/// Filters by school `id` — only changes to the viewed school trigger a refetch.
actor SchoolDetailRealtimeService: SchoolDetailRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private var channel: RealtimeChannelV2?

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func subscribe(
    schoolId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    await unsubscribe()

    logger.info("Subscribing to school detail updates for school: \(schoolId)")

    let channel = supabaseManager.client
      .realtimeV2
      .channel("school-detail-\(schoolId)")

    _ = channel.onPostgresChange(
      AnyAction.self,
      schema: "public",
      table: "schools",
      filter: "id=eq.\(schoolId)"
    ) { _ in
      Task { @MainActor in
        logger.info("Realtime: school change detected")
        onChange()
      }
    }

    do {
      try await channel.subscribeWithError()
      self.channel = channel
      logger.info("Subscribed to school detail channel")
    } catch {
      logger.error("Failed to subscribe to school detail: \(error.localizedDescription)")
      throw error
    }
  }

  func unsubscribe() async {
    if let channel {
      await channel.unsubscribe()
      self.channel = nil
      logger.info("Unsubscribed from school detail channel")
    }
  }
}
