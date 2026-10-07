import Foundation

/// Service contract for aggregating the data displayed on the Dashboard home screen.
protocol DashboardManaging: Sendable {
  /// Returns high-level counts for the family unit. Schools, coaches and interactions are family-wide;
  /// `userId` (the target athlete) scopes offers and events, matching web.
  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats
  /// Returns all schools for the family unit (used to resolve school names in widgets).
  func fetchSchools(familyUnitId: String) async throws -> [School]
  /// Returns coaches associated with the given school IDs.
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  /// Returns recent interactions for the whole family (any member's), optionally capped at `limit`.
  func fetchInteractions(familyUnitId: String, limit: Int?) async throws -> [Interaction]
  /// Returns every family interaction at or after `since` (by `occurredAt`, or `createdAt` when it is nil).
  func fetchInteractions(familyUnitId: String, since: Date) async throws -> [Interaction]
  /// Returns the family's single newest interaction by `occurredAt` (rows without one sort last).
  func fetchLatestInteraction(familyUnitId: String) async throws -> Interaction?
  /// Returns scholarship offers received by the user.
  func fetchOffers(userId: String) async throws -> [Offer]
  /// Returns upcoming and past events for the user, optionally capped at `limit`.
  func fetchEvents(userId: String, limit: Int?) async throws -> [FullEvent]
  /// Returns performance metrics logged by the user, optionally capped at `limit`.
  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric]
  /// Fetches personalised action-item suggestions from the web API.
  /// - Parameters:
  ///   - location: The user's home location string, used for geo-relevant suggestions.
  ///   - accessToken: Bearer token for the web API; pass the Supabase session access token.
  func fetchSuggestions(location: String, accessToken: String?) async throws -> (suggestions: [Suggestion], pendingCount: Int)
  /// Marks a suggestion as dismissed so it no longer appears in the Action Items widget.
  func dismissSuggestion(id: String, accessToken: String?) async throws
  /// Marks a suggestion as completed.
  func completeSuggestion(id: String, accessToken: String?) async throws
}
