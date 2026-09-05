import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "DocumentsRealtimeService"
)

/// Protocol for managing real-time updates on the documents list page
protocol DocumentsRealtimeManaging: Sendable {
  func subscribe(
    familyUnitId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws

  func unsubscribe() async
}

/// Subscribes to Supabase Realtime postgres_changes on the `documents` table
/// so the documents page updates live when a family member uploads, edits,
/// or deletes a document from another device/session.
///
/// Filters by `family_unit_id` — broader than the read query (which uses
/// user_id) but ensures the page catches changes from any family member.
/// The refetch callback re-queries with the composable's own user_id filter.
actor DocumentsRealtimeService: DocumentsRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private var channel: RealtimeChannelV2?

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func subscribe(
    familyUnitId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    await unsubscribe()

    logger.info("Subscribing to documents updates for family: \(familyUnitId)")

    let channel = supabaseManager.client
      .realtimeV2
      .channel("documents-list-\(familyUnitId)")

    _ = channel.onPostgresChange(
      AnyAction.self,
      schema: "public",
      table: "documents",
      filter: "family_unit_id=eq.\(familyUnitId)"
    ) { _ in
      Task { @MainActor in
        logger.info("Realtime: document change detected")
        onChange()
      }
    }

    do {
      try await channel.subscribeWithError()
      self.channel = channel
      logger.info("Subscribed to documents channel")
    } catch {
      logger.error("Failed to subscribe to documents: \(error.localizedDescription)")
      throw error
    }
  }

  func unsubscribe() async {
    if let channel {
      await channel.unsubscribe()
      self.channel = nil
      logger.info("Unsubscribed from documents channel")
    }
  }
}
