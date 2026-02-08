import Foundation
@testable import TheRecruitingCompass

final class MockDashboardService: DashboardManaging, @unchecked Sendable {
  // MARK: - Call Counts

  var fetchStatsCallCount = 0
  var fetchSchoolsCallCount = 0
  var fetchCoachesCallCount = 0
  var fetchInteractionsCallCount = 0
  var fetchOffersCallCount = 0
  var fetchEventsCallCount = 0
  var fetchMetricsCallCount = 0
  var fetchRecentActivityCallCount = 0
  var fetchSuggestionsCallCount = 0
  var dismissSuggestionCallCount = 0

  // MARK: - Captured Arguments

  var lastFetchStatsFamilyUnitId: String?
  var lastFetchStatsUserId: String?
  var lastDismissedSuggestionId: String?

  // MARK: - Error Flags

  var shouldThrowFetchStats = false
  var shouldThrowFetchSuggestions = false
  var shouldThrowFetchEvents = false
  var shouldThrowFetchActivities = false
  var shouldThrowFetchMetrics = false
  var shouldThrowFetchInteractions = false
  var shouldThrowDismissSuggestion = false

  // MARK: - Configurable Return Values

  var stubbedStats = DashboardStats(
    coachCount: 5,
    schoolCount: 10,
    interactionCount: 20,
    totalOffers: 3,
    acceptedOffers: 1,
    aTierSchoolCount: 2,
    acceptanceRate: 0.33
  )
  var stubbedSchools: [School] = []
  var stubbedCoaches: [Coach] = []
  var stubbedInteractions: [Interaction] = []
  var stubbedOffers: [Offer] = []
  var stubbedEvents: [Event] = []
  var stubbedMetrics: [PerformanceMetric] = []
  var stubbedActivities: [Activity] = []
  var stubbedSuggestions: [Suggestion] = []

  // MARK: - DashboardManaging

  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats {
    fetchStatsCallCount += 1
    lastFetchStatsFamilyUnitId = familyUnitId
    lastFetchStatsUserId = userId
    if shouldThrowFetchStats {
      throw NSError(domain: "MockDashboard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock fetch stats error"])
    }
    return stubbedStats
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    fetchSchoolsCallCount += 1
    return stubbedSchools
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    fetchCoachesCallCount += 1
    return stubbedCoaches
  }

  func fetchInteractions(userId: String, limit: Int?) async throws -> [Interaction] {
    fetchInteractionsCallCount += 1
    if shouldThrowFetchInteractions {
      throw NSError(domain: "MockDashboard", code: 6, userInfo: [NSLocalizedDescriptionKey: "Mock fetch interactions error"])
    }
    return stubbedInteractions
  }

  func fetchOffers(userId: String) async throws -> [Offer] {
    fetchOffersCallCount += 1
    return stubbedOffers
  }

  func fetchEvents(userId: String, limit: Int?) async throws -> [Event] {
    fetchEventsCallCount += 1
    if shouldThrowFetchEvents {
      throw NSError(domain: "MockDashboard", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock fetch events error"])
    }
    return stubbedEvents
  }

  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric] {
    fetchMetricsCallCount += 1
    if shouldThrowFetchMetrics {
      throw NSError(domain: "MockDashboard", code: 4, userInfo: [NSLocalizedDescriptionKey: "Mock fetch metrics error"])
    }
    return stubbedMetrics
  }

  func fetchRecentActivity(userId: String, limit: Int) async throws -> [Activity] {
    fetchRecentActivityCallCount += 1
    if shouldThrowFetchActivities {
      throw NSError(domain: "MockDashboard", code: 5, userInfo: [NSLocalizedDescriptionKey: "Mock fetch activities error"])
    }
    return stubbedActivities
  }

  func fetchSuggestions(location: String) async throws -> [Suggestion] {
    fetchSuggestionsCallCount += 1
    if shouldThrowFetchSuggestions {
      throw NSError(domain: "MockDashboard", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock fetch suggestions error"])
    }
    return stubbedSuggestions
  }

  func dismissSuggestion(id: String) async throws {
    dismissSuggestionCallCount += 1
    lastDismissedSuggestionId = id
    if shouldThrowDismissSuggestion {
      throw NSError(domain: "MockDashboard", code: 7, userInfo: [NSLocalizedDescriptionKey: "Mock dismiss suggestion error"])
    }
  }
}
