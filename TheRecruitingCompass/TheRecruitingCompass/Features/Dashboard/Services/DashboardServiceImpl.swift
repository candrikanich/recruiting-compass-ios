import Foundation
import Supabase

final class DashboardServiceImpl: DashboardManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  @MainActor
  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats {
    async let schools = fetchSchools(familyUnitId: familyUnitId)
    async let offers = fetchOffers(userId: userId)
    async let interactions = fetchInteractions(userId: userId, limit: nil)

    let (schoolList, offerList, interactionList) = try await (schools, offers, interactions)

    let schoolIds = schoolList.map(\.id)
    let coaches = try await fetchCoaches(schoolIds: schoolIds)

    let coachCount = coaches.count
    let schoolCount = schoolList.count
    let interactionCount = interactionList.count
    let totalOffers = offerList.count
    let acceptedOffers = offerList.filter { $0.status == "accepted" }.count
    let aTierSchoolCount = schoolList.filter { $0.tier == "A" }.count
    let acceptanceRate = totalOffers > 0 ? Double(acceptedOffers) / Double(totalOffers) : nil

    return DashboardStats(
      coachCount: coachCount,
      schoolCount: schoolCount,
      interactionCount: interactionCount,
      totalOffers: totalOffers,
      acceptedOffers: acceptedOffers,
      aTierSchoolCount: aTierSchoolCount,
      acceptanceRate: acceptanceRate
    )
  }

  @MainActor
  func fetchSchools(familyUnitId: String) async throws -> [School] {
    let response: [School] = try await supabaseManager.client
      .from("schools")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value
    return response
  }

  @MainActor
  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    guard !schoolIds.isEmpty else { return [] }
    let response: [Coach] = try await supabaseManager.client
      .from("coaches")
      .select()
      .in("school_id", values: schoolIds)
      .execute()
      .value
    return response
  }

  @MainActor
  func fetchInteractions(userId: String, limit: Int?) async throws -> [Interaction] {
    var query = supabaseManager.client
      .from("interactions")
      .select()
      .eq("logged_by", value: userId)
      .order("interaction_date", ascending: false)

    if let limit = limit {
      query = query.limit(limit)
    }

    let response: [Interaction] = try await query.execute().value
    return response
  }

  @MainActor
  func fetchOffers(userId: String) async throws -> [Offer] {
    let response: [Offer] = try await supabaseManager.client
      .from("offers")
      .select()
      .eq("user_id", value: userId)
      .execute()
      .value
    return response
  }

  @MainActor
  func fetchEvents(userId: String, limit: Int?) async throws -> [Event] {
    var query = supabaseManager.client
      .from("events")
      .select()
      .eq("user_id", value: userId)
      .order("event_date", ascending: true)

    if let limit = limit {
      query = query.limit(limit)
    }

    let response: [Event] = try await query.execute().value
    return response
  }

  @MainActor
  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric] {
    var query = supabaseManager.client
      .from("performance_metrics")
      .select()
      .eq("user_id", value: userId)
      .order("recorded_date", ascending: false)

    if let limit = limit {
      query = query.limit(limit)
    }

    let response: [PerformanceMetric] = try await query.execute().value
    return response
  }

  @MainActor
  func fetchRecentActivity(userId: String, limit: Int) async throws -> [Activity] {
    let response: [Activity] = try await supabaseManager.client
      .from("activity_log")
      .select()
      .eq("user_id", value: userId)
      .order("timestamp", ascending: false)
      .limit(limit)
      .execute()
      .value
    return response
  }

  @MainActor
  func fetchSuggestions(location: String) async throws -> [Suggestion] {
    let response: [Suggestion] = try await supabaseManager.client
      .from("suggestions")
      .select()
      .eq("location", value: location)
      .execute()
      .value
    return response
  }

  @MainActor
  func dismissSuggestion(id: String) async throws {
    try await supabaseManager.client
      .from("suggestions")
      .delete()
      .eq("id", value: id)
      .execute()
  }
}
