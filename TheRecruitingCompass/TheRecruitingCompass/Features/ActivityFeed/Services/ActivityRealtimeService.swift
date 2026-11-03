import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ActivityRealtimeService"
)

enum ActivityRealtimeError: LocalizedError {
  case subscriptionFailed
  /// `unsubscribe()` (or a newer `subscribe()`) ended this subscription while it was still joining.
  case subscriptionSuperseded

  var errorDescription: String? {
    switch self {
    case .subscriptionFailed:
      return "Failed to subscribe to realtime updates"
    case .subscriptionSuperseded:
      return "Realtime subscription was superseded"
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
  private let registry = ChannelRegistry<RealtimeChannelV2>()

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
    guard try await join(interactions, generation: generation, label: "interactions") else {
      throw ActivityRealtimeError.subscriptionSuperseded
    }

    let schools = realtime.exclusiveChannel("activity-schools-\(familyUnitId)")
    _ = schools.onPostgresChange(AnyAction.self, schema: "public", table: "schools", filter: filter) { _ in
      Task { @MainActor in onSchoolsChange() }
    }
    guard try await join(schools, generation: generation, label: "schools") else {
      throw ActivityRealtimeError.subscriptionSuperseded
    }

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
    guard try await join(documents, generation: generation, label: "documents") else {
      throw ActivityRealtimeError.subscriptionSuperseded
    }

    await joinStatusHistory(familyUnitId: familyUnitId, generation: generation, onInsert: onStatusHistoryInsert)

    logger.info("Successfully subscribed to all activity channels")
  }

  func unsubscribe() async {
    logger.info("Unsubscribing from all activity channels")
    for channel in registry.drain() {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
    }
  }

  /// Joins `channel`; see `ChannelRegistry.join`.
  /// - Returns: false when the subscription was superseded and the caller must stop.
  private func join(_ channel: RealtimeChannelV2, generation: Int, label: String) async throws -> Bool {
    do {
      return try await registry.join(
        channel, generation: generation,
        subscribe: { try await channel.subscribeWithError() },
        remove: { await self.supabaseManager.client.realtimeV2.removeChannel($0) }
      )
    } catch {
      logger.error("Failed to subscribe to \(label): \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }
  }

  /// Its own channel and its own function: the history table has no family column, so a multi-family user also
  /// receives the other family's rows here. It only receives `onInsert` (a payload-free "something changed" signal),
  /// so a row can never be rendered. And it is best-effort: while the table is not in the realtime publication the
  /// server rejects this channel, which must not take the feed's other channels down with it.
  private func joinStatusHistory(
    familyUnitId: String,
    generation: Int,
    onInsert: @escaping @MainActor @Sendable () -> Void
  ) async {
    let channel = supabaseManager.client.realtimeV2.exclusiveChannel("activity-status-\(familyUnitId)")
    _ = channel.onPostgresChange(
      InsertAction.self, schema: "public", table: Self.statusHistoryTable, filter: Self.statusHistoryFilter
    ) { _ in
      Task { @MainActor in onInsert() }
    }
    let adopted = await registry.joinBestEffort(
      channel, generation: generation,
      subscribe: { try await channel.subscribeWithError() },
      remove: { await self.supabaseManager.client.realtimeV2.removeChannel($0) },
      onFailure: { logger.info("Status-history channel unavailable (\($0.localizedDescription)); using schools reload") }
    )
    if !adopted { logger.debug("Status-history channel not adopted") }
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
/// A class on purpose: the owning actor is reentrant, and `join` suspends between reading and writing it.
final class ChannelRegistry<Channel> {
  private(set) var generation = 0
  private var channels: [Channel] = []

  func adopt(_ channel: Channel, generation joinedFor: Int) -> Bool {
    guard joinedFor == generation else { return false }
    channels.append(channel)
    return true
  }

  func drain() -> [Channel] {
    generation += 1
    defer { channels = [] }
    return channels
  }

  /// Subscribes `channel`, then adopts it for `generation`. If the subscription ended while joining, or the join
  /// failed, the channel is removed instead.
  /// - Returns: true when adopted, false when superseded. Throws the join's error after removing the channel.
  func join(
    _ channel: Channel,
    generation: Int,
    subscribe: () async throws -> Void,
    remove: (Channel) async -> Void
  ) async throws -> Bool {
    do {
      try await subscribe()
    } catch {
      await remove(channel)
      throw error
    }
    guard adopt(channel, generation: generation) else {
      await remove(channel)
      return false
    }
    return true
  }

  /// Like `join`, but a failed join is reported to `onFailure` and swallowed; true only when adopted.
  func joinBestEffort(
    _ channel: Channel,
    generation: Int,
    subscribe: () async throws -> Void,
    remove: (Channel) async -> Void,
    onFailure: (Error) -> Void
  ) async -> Bool {
    do {
      return try await join(channel, generation: generation, subscribe: subscribe, remove: remove)
    } catch {
      onFailure(error)
      return false
    }
  }
}
