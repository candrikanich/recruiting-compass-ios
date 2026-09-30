import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "DashboardRealtimeService"
)

/// Protocol for managing real-time updates on the dashboard
protocol DashboardRealtimeManaging: Sendable {
  func subscribe(
    familyUnitId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws

  func unsubscribe() async
}

/// Subscribes to Supabase Realtime postgres_changes on `schools` and
/// `interactions` tables so the dashboard updates live when data changes
/// from another device, session, or family member.
///
/// Both channels filter by `family_unit_id`. Coaches are excluded because
/// they lack family_unit_id; the dashboard's refresh() re-fetches all
/// entity types anyway.
actor DashboardRealtimeService: DashboardRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private var schoolsChannel: RealtimeChannelV2?
  private var interactionsChannel: RealtimeChannelV2?

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func subscribe(
    familyUnitId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    await unsubscribe()

    logger.info("Subscribing to dashboard updates for family: \(familyUnitId)")

    // Schools channel
    let schoolsCh = supabaseManager.client
      .realtimeV2
      .exclusiveChannel("dashboard-schools-\(familyUnitId)")

    _ = schoolsCh.onPostgresChange(
      AnyAction.self,
      schema: "public",
      table: "schools",
      filter: "family_unit_id=eq.\(familyUnitId)"
    ) { _ in
      Task { @MainActor in
        logger.info("Realtime: dashboard school change detected")
        onChange()
      }
    }

    do {
      try await schoolsCh.subscribeWithError()
      self.schoolsChannel = schoolsCh
    } catch {
      await supabaseManager.client.realtimeV2.removeChannel(schoolsCh)
      logger.error("Failed to subscribe to dashboard schools: \(error.localizedDescription)")
      throw error
    }

    // Interactions channel
    let interactionsCh = supabaseManager.client
      .realtimeV2
      .exclusiveChannel("dashboard-interactions-\(familyUnitId)")

    _ = interactionsCh.onPostgresChange(
      AnyAction.self,
      schema: "public",
      table: "interactions",
      filter: "family_unit_id=eq.\(familyUnitId)"
    ) { _ in
      Task { @MainActor in
        logger.info("Realtime: dashboard interaction change detected")
        onChange()
      }
    }

    do {
      try await interactionsCh.subscribeWithError()
      self.interactionsChannel = interactionsCh
    } catch {
      await supabaseManager.client.realtimeV2.removeChannel(interactionsCh)
      logger.error("Failed to subscribe to dashboard interactions: \(error.localizedDescription)")
      throw error
    }

    logger.info("Subscribed to all dashboard channels")
  }

  func unsubscribe() async {
    if let channel = schoolsChannel {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
      schoolsChannel = nil
    }
    if let channel = interactionsChannel {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
      interactionsChannel = nil
    }
    logger.info("Unsubscribed from dashboard channels")
  }
}
