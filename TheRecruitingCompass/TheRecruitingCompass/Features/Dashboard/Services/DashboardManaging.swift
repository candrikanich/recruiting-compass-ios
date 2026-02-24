import Foundation

protocol DashboardManaging: Sendable {
  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach]
  func fetchInteractions(userId: String, limit: Int?) async throws -> [Interaction]
  func fetchOffers(userId: String) async throws -> [Offer]
  func fetchEvents(userId: String, limit: Int?) async throws -> [FullEvent]
  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric]
  func fetchSuggestions(location: String, accessToken: String?) async throws -> (suggestions: [Suggestion], pendingCount: Int)
  func dismissSuggestion(id: String, accessToken: String?) async throws
  func completeSuggestion(id: String, accessToken: String?) async throws
}
