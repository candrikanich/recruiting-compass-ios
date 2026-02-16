import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ActivityRealtimeService"
)

/// Real-time activity feed service using Supabase Realtime subscriptions
actor ActivityRealtimeService: ActivityRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private let activityService: any ActivityFeedManaging

  private var interactionsChannel: RealtimeChannelV2?
  private var statusChangesChannel: RealtimeChannelV2?
  private var documentsChannel: RealtimeChannelV2?

  init(
    supabaseManager: SupabaseManager = .shared,
    activityService: (any ActivityFeedManaging)? = nil
  ) {
    self.supabaseManager = supabaseManager
    self.activityService = activityService ?? ActivityFeedServiceImpl(supabaseManager: supabaseManager)
  }

  // MARK: - ActivityRealtimeManaging

  func subscribe(
    userId: String,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void
  ) async throws {
    logger.info("Subscribing to realtime activity updates for user: \(userId)")

    // Subscribe to interactions table
    let interactionsChannel = supabaseManager.client
      .realtimeV2
      .channel("activity-interactions-\(userId)")

    interactionsChannel
      .onPostgresChange(
        InsertAction.self,
        schema: "public",
        table: "interactions",
        filter: "logged_by=eq.\(userId)"
      ) { [weak self] action in
        guard let self = self else { return }
        Task { @MainActor in
          await self.handleInteractionInsert(record: action.record, onInsert: onInsert)
        }
      }

    await interactionsChannel.subscribe()
    self.interactionsChannel = interactionsChannel

    // Subscribe to school_status_history table
    let statusChangesChannel = supabaseManager.client
      .realtimeV2
      .channel("activity-status-\(userId)")

    statusChangesChannel
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

    await statusChangesChannel.subscribe()
    self.statusChangesChannel = statusChangesChannel

    // Subscribe to documents table
    let documentsChannel = supabaseManager.client
      .realtimeV2
      .channel("activity-documents-\(userId)")

    documentsChannel
      .onPostgresChange(
        InsertAction.self,
        schema: "public",
        table: "documents",
        filter: "user_id=eq.\(userId)"
      ) { [weak self] action in
        guard let self = self else { return }
        Task { @MainActor in
          await self.handleDocumentInsert(record: action.record, onInsert: onInsert)
        }
      }

    await documentsChannel.subscribe()
    self.documentsChannel = documentsChannel

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
      // Decode the interaction
      let interaction = try record.decode(as: Interaction.self)

      // Fetch school name if needed
      var schoolName: String?
      if let schoolId = interaction.schoolId {
        let schoolNames = try await activityService.fetchSchoolNames(schoolIds: [schoolId])
        schoolName = schoolNames[schoolId]
      }

      // Transform to ActivityEvent
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
      // Decode the status change
      let statusChange = try record.decode(as: SchoolStatusHistory.self)

      // Fetch school name
      let schoolNames = try await activityService.fetchSchoolNames(schoolIds: [statusChange.schoolId])
      let schoolName = schoolNames[statusChange.schoolId]

      // Transform to ActivityEvent
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
      // Decode the document
      let document = try record.decode(as: DocumentRecord.self)

      // Transform to ActivityEvent
      let event = ActivityEventFactory.fromDocument(document)

      logger.debug("Received realtime document insert: \(event.id)")
      onInsert(event)
    } catch {
      logger.error("Failed to process realtime document: \(error.localizedDescription)")
    }
  }
}
