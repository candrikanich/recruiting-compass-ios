import Foundation
import OSLog
import Supabase

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ActivityRealtimeService"
)

enum ActivityRealtimeError: LocalizedError, Equatable {
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
    let schools = realtime.exclusiveChannel("activity-schools-\(familyUnitId)")
    _ = schools.onPostgresChange(AnyAction.self, schema: "public", table: "schools", filter: filter) { _ in
      Task { @MainActor in onSchoolsChange() }
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
    // Own channel and own function (receives only the payload-free signal), so a history row can never be rendered.
    let statusHistory = makeStatusHistoryChannel(familyUnitId: familyUnitId, onInsert: onStatusHistoryInsert)

    do {
      try await registry.joinAll(
        required: [
          .init(channel: interactions, subscribe: { try await interactions.subscribeWithError() }),
          .init(channel: schools, subscribe: { try await schools.subscribeWithError() }),
          .init(channel: documents, subscribe: { try await documents.subscribeWithError() })
        ],
        bestEffort: .init(channel: statusHistory, subscribe: { try await statusHistory.subscribeWithError() }),
        generation: generation,
        remove: { await self.supabaseManager.client.realtimeV2.removeChannel($0) },
        onBestEffortFailure: {
          logger.info("Status-history channel unavailable (\($0.localizedDescription)); using schools reload")
        }
      )
    } catch ActivityRealtimeError.subscriptionSuperseded {
      logger.info("Subscription superseded while joining; channels removed")
      throw ActivityRealtimeError.subscriptionSuperseded
    } catch {
      logger.error("Failed to subscribe to activity channels: \(error.localizedDescription)")
      throw ActivityRealtimeError.subscriptionFailed
    }

    logger.info("Successfully subscribed to activity channels")
  }

  func unsubscribe() async {
    logger.info("Unsubscribing from all activity channels")
    for channel in registry.drain() {
      await supabaseManager.client.realtimeV2.removeChannel(channel)
    }
  }

  /// The history table has no family column, so a multi-family user also receives the other family's rows here:
  /// this only ever reports "something changed" (no payload), and the join is best-effort. While the table is not in
  /// the realtime publication the server rejects this channel, which must not take the feed's other channels down.
  private func makeStatusHistoryChannel(
    familyUnitId: String,
    onInsert: @escaping @MainActor @Sendable () -> Void
  ) -> RealtimeChannelV2 {
    let channel = supabaseManager.client.realtimeV2.exclusiveChannel("activity-status-\(familyUnitId)")
    _ = channel.onPostgresChange(
      InsertAction.self, schema: "public", table: Self.statusHistoryTable, filter: Self.statusHistoryFilter
    ) { _ in
      Task { @MainActor in onInsert() }
    }
    return channel
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

  struct Step {
    let channel: Channel
    let subscribe: () async throws -> Void
  }

  /// Subscribes `channel`, then adopts it for `generation`. If the subscription ended while joining, or the join
  /// failed, the channel is removed instead.
  /// `isolation` keeps this on the caller's actor: the registry is actor-confined state, and `adopt` must not
  /// run on the global executor while the actor calls `drain`.
  /// - Returns: true when adopted, false when superseded. Throws the join's error after removing the channel.
  func join(
    _ channel: Channel,
    generation: Int,
    subscribe: () async throws -> Void,
    remove: (Channel) async -> Void,
    isolation: isolated (any Actor)? = #isolation
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
    onFailure: (Error) -> Void,
    isolation: isolated (any Actor)? = #isolation
  ) async -> Bool {
    do {
      return try await join(channel, generation: generation, subscribe: subscribe, remove: remove)
    } catch {
      onFailure(error)
      return false
    }
  }

  /// Joins the required channels in order, then the best-effort one last. A required join that finds the
  /// subscription superseded throws `subscriptionSuperseded`; a failing required join throws its error and the
  /// best-effort channel is not attempted. A failing best-effort join is reported and leaves the rest adopted.
  func joinAll(
    required: [Step],
    bestEffort: Step,
    generation: Int,
    remove: (Channel) async -> Void,
    onBestEffortFailure: (Error) -> Void,
    isolation: isolated (any Actor)? = #isolation
  ) async throws {
    for (index, step) in required.enumerated() {
      let adopted: Bool
      do {
        adopted = try await join(step.channel, generation: generation, subscribe: step.subscribe, remove: remove)
      } catch {
        await removeUnjoined(Array(required[(index + 1)...]) + [bestEffort], remove: remove)
        throw error
      }
      guard adopted else {
        await removeUnjoined(Array(required[(index + 1)...]) + [bestEffort], remove: remove)
        throw ActivityRealtimeError.subscriptionSuperseded
      }
    }
    _ = await joinBestEffort(
      bestEffort.channel, generation: generation, subscribe: bestEffort.subscribe, remove: remove,
      onFailure: onBestEffortFailure)
  }

  /// Channels that were created but never reached `join` would otherwise stay registered with the client.
  private func removeUnjoined(_ steps: [Step], remove: (Channel) async -> Void) async {
    for step in steps { await remove(step.channel) }
  }
}
