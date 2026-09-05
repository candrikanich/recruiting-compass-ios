import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ActivityRealtimeService"
)

enum ActivityRealtimeError: LocalizedError {
  case subscriptionFailed

  var errorDescription: String? {
    switch self {
    case .subscriptionFailed:
      return "Failed to subscribe to realtime updates"
    }
  }
}

/// Real-time activity feed service using Supabase Realtime subscriptions.
///
/// Subscribes to interactions (family_unit_id), documents (family_unit_id),
/// and school_status_history (changed_by — lacks family_unit_id).
/// INSERTs are decoded and enriched for instant feed append; UPDATE/DELETE
/// trigger a full reload via the `onChange` callback.
actor ActivityRealtimeService: ActivityRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private let activityService: any ActivityFeedManaging

  private var interactionsChannel: RealtimeChannelV2?
  private var statusChangesChannel: RealtimeChannelV2?
  private var documentsChannel: RealtimeChannelV2?

  init(
    supabaseManager: SupabaseManager,
    activityService: (any ActivityFeedManaging)? = nil
  ) {
    self.supabaseManager = supabaseManager
    self.activityService = activityService ?? ActivityFeedServiceImpl(supabaseManager: supabaseManager)
  }

  // MARK: - ActivityRealtimeManaging

  func subscribe(
    userId: String,
    familyUnitId: String?,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    logger.info("Subscribing to realtime activity updates for user: \(userId), family: \(familyUnitId ?? "none")")

    // Interactions — use family_unit_id when available (catches family member changes)
    let interactionsFilter = familyUnitId.map { "family_unit_id=eq.\($0)" } ?? "logged_by=eq.\(userId)"
    let interactionsChannel = supabaseManager.client
      .realtimeV2
      .channel("activity-interactions-\(familyUnitId ?? userId)")

    _ = interactionsChannel
      .onPostgresChange(
        InsertAction.self,
        schema: "public",
        table: "interactions",
        filter: interactionsFilter
      ) { [weak self] action in
        guard let self = self else { return }
        Task { @MainActor in
          await self.handleInteractionInsert(record: action.record, onInsert: onInsert)
        }
      }

    _ = interactionsChannel
      .onPostgresChange(
        UpdateAction.self,
        schema: "public",
        table: "interactions",
        filter: interactionsFilter
      ) { _ in
        Task { @MainActor in onChange() }
      }

    _ = interactionsChannel
      .onPostgresChange(
        DeleteAction.self,
        schema: "public",
        table: "interactions",
        filter: interactionsFilter
      ) { _ in
        Task { @MainActor in onChange() }
      }

    do {
      try await interactionsChannel.subscribeWithError()
      self.interactionsChannel = interactionsChannel
    } catch {
      logger.error("Failed to subscribe to interactions: \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }

    // School status history — no family_unit_id column, stays user-scoped
    let statusChangesChannel = supabaseManager.client
      .realtimeV2
      .channel("activity-status-\(userId)")

    _ = statusChangesChannel
      .onPostgresChange(
        InsertAction.self,
        schema: "public",
        table: "school_status_history",
        filter: "changed_by=eq.\(userId)"
      ) { [weak self] action in
        guard let self = self else { return }
        Task { @MainActor in
          await self.handleStatusChangeInsert(record: action.record, onInsert: onInsert)
        }
      }

    _ = statusChangesChannel
      .onPostgresChange(
        UpdateAction.self,
        schema: "public",
        table: "school_status_history",
        filter: "changed_by=eq.\(userId)"
      ) { _ in
        Task { @MainActor in onChange() }
      }

    _ = statusChangesChannel
      .onPostgresChange(
        DeleteAction.self,
        schema: "public",
        table: "school_status_history",
        filter: "changed_by=eq.\(userId)"
      ) { _ in
        Task { @MainActor in onChange() }
      }

    do {
      try await statusChangesChannel.subscribeWithError()
      self.statusChangesChannel = statusChangesChannel
    } catch {
      logger.error("Failed to subscribe to status changes: \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }

    // Documents — use family_unit_id when available
    let documentsFilter = familyUnitId.map { "family_unit_id=eq.\($0)" } ?? "user_id=eq.\(userId)"
    let documentsChannel = supabaseManager.client
      .realtimeV2
      .channel("activity-documents-\(familyUnitId ?? userId)")

    _ = documentsChannel
      .onPostgresChange(
        InsertAction.self,
        schema: "public",
        table: "documents",
        filter: documentsFilter
      ) { [weak self] action in
        guard let self = self else { return }
        Task { @MainActor in
          await self.handleDocumentInsert(record: action.record, onInsert: onInsert)
        }
      }

    _ = documentsChannel
      .onPostgresChange(
        UpdateAction.self,
        schema: "public",
        table: "documents",
        filter: documentsFilter
      ) { _ in
        Task { @MainActor in onChange() }
      }

    _ = documentsChannel
      .onPostgresChange(
        DeleteAction.self,
        schema: "public",
        table: "documents",
        filter: documentsFilter
      ) { _ in
        Task { @MainActor in onChange() }
      }

    do {
      try await documentsChannel.subscribeWithError()
      self.documentsChannel = documentsChannel
    } catch {
      logger.error("Failed to subscribe to documents: \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }

    logger.info("Successfully subscribed to all activity channels")
  }

  func unsubscribe() async {
    logger.info("Unsubscribing from all activity channels")

    if let channel = interactionsChannel {
      await channel.unsubscribe()
      interactionsChannel = nil
    }

    if let channel = statusChangesChannel {
      await channel.unsubscribe()
      statusChangesChannel = nil
    }

    if let channel = documentsChannel {
      await channel.unsubscribe()
      documentsChannel = nil
    }

    logger.info("Unsubscribed from all activity channels")
  }

  // MARK: - Private Helpers

  @MainActor
  private func handleInteractionInsert(
    record: JSONObject,
    onInsert: @MainActor @Sendable (ActivityEvent) -> Void
  ) async {

    do {
      let interaction = try record.decode(as: Interaction.self)

      var schoolName: String?
      if let schoolId = interaction.schoolId {
        let schoolNames = try await activityService.fetchSchoolNames(schoolIds: [schoolId])
        schoolName = schoolNames[schoolId]
      }

      let event = ActivityEventFactory.fromInteraction(interaction, schoolName: schoolName)

      logger.debug("Received realtime interaction insert: \(event.id)")
      onInsert(event)
    } catch {
      logger.error("Failed to process realtime interaction: \(error.localizedDescription)")
    }
  }

  @MainActor
  private func handleStatusChangeInsert(
    record: JSONObject,
    onInsert: @MainActor @Sendable (ActivityEvent) -> Void
  ) async {

    do {
      let statusChange = try record.decode(as: SchoolStatusHistory.self)

      let schoolNames = try await activityService.fetchSchoolNames(schoolIds: [statusChange.schoolId])
      let schoolName = schoolNames[statusChange.schoolId]

      let event = ActivityEventFactory.fromStatusChange(statusChange, schoolName: schoolName)

      logger.debug("Received realtime status change insert: \(event.id)")
      onInsert(event)
    } catch {
      logger.error("Failed to process realtime status change: \(error.localizedDescription)")
    }
  }

  @MainActor
  private func handleDocumentInsert(
    record: JSONObject,
    onInsert: @MainActor @Sendable (ActivityEvent) -> Void
  ) async {

    do {
      let document = try record.decode(as: DocumentRecord.self)

      let event = ActivityEventFactory.fromDocument(document)

      logger.debug("Received realtime document insert: \(event.id)")
      onInsert(event)
    } catch {
      logger.error("Failed to process realtime document: \(error.localizedDescription)")
    }
  }
}
