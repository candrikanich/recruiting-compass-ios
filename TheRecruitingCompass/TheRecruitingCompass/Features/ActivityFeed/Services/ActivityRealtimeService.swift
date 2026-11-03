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
  private var registry = ChannelRegistry<RealtimeChannelV2>()

  init(
    supabaseManager: SupabaseManager,
    activityService: (any ActivityFeedManaging)? = nil
  ) {
    self.supabaseManager = supabaseManager
    self.activityService = activityService ?? ActivityFeedServiceImpl(supabaseManager: supabaseManager)
  }

  /// The one place the feed's realtime scope is defined: every table is filtered to the active family.
  nonisolated static func familyFilter(_ familyUnitId: String) -> String {
    "family_unit_id=eq.\(familyUnitId)"
  }

  static let statusHistoryTable = "school_status_history"
  /// No filter: the table has no family column. RLS limits delivery to the user's families.
  static let statusHistoryFilter: String? = nil
  /// INSERT only: the history is append-only, and an UPDATE/DELETE of an old row changes nothing the feed shows.
  static let statusHistoryEvent: PostgresChangeEvent = .insert

  // MARK: - ActivityRealtimeManaging

  func subscribe(
    familyUnitId: String,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void,
    onChange: @escaping @MainActor @Sendable () -> Void,
    onSchoolsChange: @escaping @MainActor @Sendable () -> Void,
    onStatusHistoryInsert: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    await unsubscribe()
    let generation = registry.generation

    logger.info("Subscribing to realtime activity updates for family: \(familyUnitId)")

    let filter = Self.familyFilter(familyUnitId)
    let realtime = supabaseManager.client.realtimeV2

    let interactions = realtime.exclusiveChannel("activity-interactions-\(familyUnitId)")
    _ = interactions.onPostgresChange(InsertAction.self, schema: "public", table: "interactions", filter: filter) {
      [weak self] action in
      guard let self else { return }
      Task { @MainActor in await self.handleInteractionInsert(record: action.record, onInsert: onInsert) }
    }
    _ = interactions.onPostgresChange(UpdateAction.self, schema: "public", table: "interactions", filter: filter) { _ in
      Task { @MainActor in onChange() }
    }
    _ = interactions.onPostgresChange(DeleteAction.self, schema: "public", table: "interactions", filter: filter) { _ in
      Task { @MainActor in onChange() }
    }
    guard try await join(interactions, generation: generation, label: "interactions") else { return }

    let schools = realtime.exclusiveChannel("activity-schools-\(familyUnitId)")
    _ = schools.onPostgresChange(AnyAction.self, schema: "public", table: "schools", filter: filter) { _ in
      Task { @MainActor in onSchoolsChange() }
    }
    guard try await join(schools, generation: generation, label: "schools") else { return }

    let statusHistory = realtime.exclusiveChannel("activity-status-\(familyUnitId)")
    let notify: @Sendable () -> Void = { Task { @MainActor in onStatusHistoryInsert() } }
    switch Self.statusHistoryEvent {
    case .insert:
      _ = statusHistory.onPostgresChange(
        InsertAction.self, schema: "public", table: Self.statusHistoryTable, filter: Self.statusHistoryFilter
      ) { _ in notify() }
    case .update:
      _ = statusHistory.onPostgresChange(
        UpdateAction.self, schema: "public", table: Self.statusHistoryTable, filter: Self.statusHistoryFilter
      ) { _ in notify() }
    case .delete:
      _ = statusHistory.onPostgresChange(
        DeleteAction.self, schema: "public", table: Self.statusHistoryTable, filter: Self.statusHistoryFilter
      ) { _ in notify() }
    case .all:
      _ = statusHistory.onPostgresChange(
        AnyAction.self, schema: "public", table: Self.statusHistoryTable, filter: Self.statusHistoryFilter
      ) { _ in notify() }
    }
    guard try await join(statusHistory, generation: generation, label: "status history") else { return }

    let documents = realtime.exclusiveChannel("activity-documents-\(familyUnitId)")
    _ = documents.onPostgresChange(InsertAction.self, schema: "public", table: "documents", filter: filter) {
      [weak self] action in
      guard let self else { return }
      Task { @MainActor in await self.handleDocumentInsert(record: action.record, onInsert: onInsert) }
    }
    _ = documents.onPostgresChange(UpdateAction.self, schema: "public", table: "documents", filter: filter) { _ in
      Task { @MainActor in onChange() }
    }
    _ = documents.onPostgresChange(DeleteAction.self, schema: "public", table: "documents", filter: filter) { _ in
      Task { @MainActor in onChange() }
    }
    guard try await join(documents, generation: generation, label: "documents") else { return }

    logger.info("Successfully subscribed to all activity channels")
  }

  func unsubscribe() async {
    logger.info("Unsubscribing from all activity channels")
    for channel in registry.drain() {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
    }
  }

  /// Joins `channel`. This actor is reentrant: `unsubscribe()` can run while the join is suspended, and
  /// then the channel belongs to a dead subscription, so it is removed instead of adopted.
  /// - Returns: false when the subscription was superseded and the caller must stop.
  private func join(_ channel: RealtimeChannelV2, generation: Int, label: String) async throws -> Bool {
    do {
      try await channel.subscribeWithError()
    } catch {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
      logger.error("Failed to subscribe to \(label): \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }
    guard registry.adopt(channel, generation: generation) else {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
      logger.info("Subscription superseded while joining \(label); channel removed")
      return false
    }
    return true
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

/// Tracks the channels of the current subscription. `drain()` ends the subscription (bumping the
/// generation), after which a channel still being joined for the old generation is refused.
struct ChannelRegistry<Channel> {
  private(set) var generation = 0
  private var channels: [Channel] = []

  mutating func adopt(_ channel: Channel, generation joinedFor: Int) -> Bool {
    guard joinedFor == generation else { return false }
    channels.append(channel)
    return true
  }

  mutating func drain() -> [Channel] {
    generation += 1
    defer { channels = [] }
    return channels
  }
}
