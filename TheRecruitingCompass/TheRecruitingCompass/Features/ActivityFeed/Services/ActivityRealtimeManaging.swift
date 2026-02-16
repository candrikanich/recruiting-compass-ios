import Foundation

/// Protocol for managing real-time activity feed updates via Supabase Realtime
protocol ActivityRealtimeManaging: Sendable {
  /// Subscribe to real-time activity updates for a user
  /// - Parameters:
  ///   - userId: The user ID to filter events by
  ///   - onInsert: Callback invoked when a new activity event is inserted (must be @Sendable)
  func subscribe(
    userId: String,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void
  ) async throws

  /// Unsubscribe from all real-time channels
  func unsubscribe() async
}
