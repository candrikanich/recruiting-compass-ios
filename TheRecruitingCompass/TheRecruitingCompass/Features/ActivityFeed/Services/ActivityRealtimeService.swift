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
/// Subscribes to interactions, documents and schools, all filtered by family_unit_id.
/// (`school_status_history` is not in the realtime publication, so a schools change stands in for it.)
/// INSERTs are decoded and enriched for instant feed append; UPDATE/DELETE
/// trigger a full reload via the `onChange` callback.
actor ActivityRealtimeService: ActivityRealtimeManaging {
  private let supabaseManager: SupabaseManager
  private let activityService: any ActivityFeedManaging

  private var interactionsChannel: RealtimeChannelV2?
  private var schoolsChannel: RealtimeChannelV2?
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
    familyUnitId: String,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void,
    onChange: @escaping @MainActor @Sendable () -> Void,
    onSchoolsChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    await unsubscribe()

    logger.info("Subscribing to realtime activity updates for family: \(familyUnitId)")

    let familyFilter = "family_unit_id=eq.\(familyUnitId)"
    let interactionsFilter = familyFilter
    let interactionsChannel = supabaseManager.client
      .realtimeV2
      .exclusiveChannel("activity-interactions-\(familyUnitId)")

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
      await supabaseManager.client.realtimeV2.removeChannel(interactionsChannel)
      logger.error("Failed to subscribe to interactions: \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }

    let schoolsChannel = supabaseManager.client
      .realtimeV2
      .exclusiveChannel("activity-schools-\(familyUnitId)")

    _ = schoolsChannel
      .onPostgresChange(
        AnyAction.self,
        schema: "public",
        table: "schools",
        filter: familyFilter
      ) { _ in
        Task { @MainActor in onSchoolsChange() }
      }

    do {
      try await schoolsChannel.subscribeWithError()
      self.schoolsChannel = schoolsChannel
    } catch {
      await supabaseManager.client.realtimeV2.removeChannel(schoolsChannel)
      logger.error("Failed to subscribe to schools: \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }

    let documentsFilter = familyFilter
    let documentsChannel = supabaseManager.client
      .realtimeV2
      .exclusiveChannel("activity-documents-\(familyUnitId)")

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
      await supabaseManager.client.realtimeV2.removeChannel(documentsChannel)
      logger.error("Failed to subscribe to documents: \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }

    logger.info("Successfully subscribed to all activity channels")
  }

  func unsubscribe() async {
    logger.info("Unsubscribing from all activity channels")

    if let channel = interactionsChannel {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
      interactionsChannel = nil
    }

    if let channel = schoolsChannel {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
      schoolsChannel = nil
    }

    if let channel = documentsChannel {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
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
