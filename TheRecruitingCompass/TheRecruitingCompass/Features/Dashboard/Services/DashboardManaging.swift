import Foundation

protocol DashboardManaging: Sendable {
  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func fetchInteractions(userId: String, limit: Int?) async throws -> [Interaction]
  func fetchOffers(userId: String) async throws -> [Offer]
  func fetchEvents(userId: String, limit: Int?) async throws -> [Event]
  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric]
  @available(*, deprecated, message: "Use ActivityFeedService instead - this fetches from deprecated activity_log table")
  func fetchRecentActivity(userId: String, limit: Int) async throws -> [Activity]
  func fetchSuggestions(location: String) async throws -> [Suggestion]
  func dismissSuggestion(id: String) async throws
  func completeSuggestion(id: String) async throws
}
