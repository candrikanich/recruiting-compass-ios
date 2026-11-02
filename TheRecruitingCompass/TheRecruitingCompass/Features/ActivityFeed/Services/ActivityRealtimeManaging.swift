import Foundation

/// Protocol for managing real-time activity feed updates via Supabase Realtime
protocol ActivityRealtimeManaging: Sendable {
  /// Subscribe to real-time activity updates for the active family.
  /// - Parameters:
  ///   - familyUnitId: The active family unit; every channel is filtered by it.
  ///   - onInsert: Callback invoked when a new interaction/document is inserted (must be @Sendable)
  ///   - onChange: Callback invoked on UPDATE/DELETE — triggers a full reload since the affected record may no longer match
  ///   - onSchoolsChange: Callback invoked when any of the family's schools changes. Status changes are an UPDATE on
  ///     `schools` followed by a separate INSERT into `school_status_history` (not in the realtime publication), so
  ///     callers should debounce a reload from this.
  func subscribe(
    familyUnitId: String,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void,
    onChange: @escaping @MainActor @Sendable () -> Void,
    onSchoolsChange: @escaping @MainActor @Sendable () -> Void
  ) async throws

  /// Unsubscribe from all real-time channels
  func unsubscribe() async
}
