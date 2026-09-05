import Foundation

/// Protocol for managing real-time activity feed updates via Supabase Realtime
protocol ActivityRealtimeManaging: Sendable {
  /// Subscribe to real-time activity updates for a user/family
  /// - Parameters:
  ///   - userId: The user ID (used for school_status_history which lacks family_unit_id)
  ///   - familyUnitId: The family unit ID (used for interactions and documents — broader scope catches family member changes)
  ///   - onInsert: Callback invoked when a new activity event is inserted (must be @Sendable)
  ///   - onChange: Callback invoked on UPDATE/DELETE — triggers a full reload since the affected record may no longer match
  func subscribe(
    userId: String,
    familyUnitId: String?,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws

  /// Unsubscribe from all real-time channels
  func unsubscribe() async
}
