import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DashboardService")

final class DashboardServiceImpl: DashboardManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  private func fetch<T: Decodable>(
    _ label: String,
    query: () async throws -> [T]
  ) async throws -> [T] {
    logger.debug("Fetching \(label)")
    do {
      let result = try await query()
      logger.info("Fetched \(result.count) \(label)")
      return result
    } catch {
      logger.error("Failed to fetch \(label): \(error.localizedDescription)")
      if let decodingError = error as? DecodingError {
        logger.error("Decoding error: \(String(describing: decodingError))")
      }
      throw error
    }
  }

  func fetchStats(familyUnitId: String, userId: String) async throws -> DashboardStats {
    logger.debug("fetchStats - familyUnitId: \(familyUnitId), userId: \(userId)")

    do {
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

      logger.info("fetchStats SUCCESS - schools: \(schoolCount), coaches: \(coachCount), interactions: \(interactionCount), offers: \(totalOffers)")

      return DashboardStats(
        coachCount: coachCount,
        schoolCount: schoolCount,
        interactionCount: interactionCount,
        totalOffers: totalOffers,
        acceptedOffers: acceptedOffers,
        aTierSchoolCount: aTierSchoolCount,
        acceptanceRate: acceptanceRate
      )
    } catch {
      logger.error("fetchStats FAILED: \(error.localizedDescription)")
      if let decodingError = error as? DecodingError {
        logger.error("Decoding error details: \(String(describing: decodingError))")
      }
      throw error
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await fetch("schools") {
      try await supabaseManager.client
        .from("schools")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .execute()
        .value
    }
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    guard !schoolIds.isEmpty else {
      logger.debug("No school IDs provided, returning empty coaches list")
      return []
    }

    return try await fetch("coaches") {
      try await supabaseManager.client
        .from("coaches")
        .select()
        .in("school_id", values: schoolIds)
        .execute()
        .value
    }
  }

  func fetchInteractions(userId: String, limit: Int?) async throws -> [Interaction] {
    try await fetch("interactions") {
      var query = supabaseManager.client
        .from("interactions")
        .select()
        .eq("logged_by", value: userId)
        .order("created_at", ascending: false)

      if let limit = limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchOffers(userId: String) async throws -> [Offer] {
    try await fetch("offers") {
      try await supabaseManager.client
        .from("offers")
        .select()
        .eq("user_id", value: userId)
        .execute()
        .value
    }
  }

  func fetchEvents(userId: String, limit: Int?) async throws -> [Event] {
    try await fetch("events") {
      var query = supabaseManager.client
        .from("events")
        .select()
        .eq("user_id", value: userId)
        .order("event_date", ascending: true)

      if let limit = limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchMetrics(userId: String, limit: Int?) async throws -> [PerformanceMetric] {
    try await fetch("metrics") {
      var query = supabaseManager.client
        .from("performance_metrics")
        .select()
        .eq("user_id", value: userId)
        .order("recorded_date", ascending: false)

      if let limit = limit {
        query = query.limit(limit)
      }

      return try await query.execute().value
    }
  }

  func fetchRecentActivity(userId: String, limit: Int) async throws -> [Activity] {
    try await fetch("recent activity") {
      try await supabaseManager.client
        .from("activity_log")
        .select()
        .eq("user_id", value: userId)
        .order("timestamp", ascending: false)
        .limit(limit)
        .execute()
        .value
    }
  }

  func fetchSuggestions(location: String) async throws -> [Suggestion] {
    try await fetch("suggestions") {
      try await supabaseManager.client
        .from("suggestions")
        .select()
        .eq("location", value: location)
        .execute()
        .value
    }
  }

  func dismissSuggestion(id: String) async throws {
    try await supabaseManager.client
      .from("suggestions")
      .delete()
      .eq("id", value: id)
      .execute()
  }

  func completeSuggestion(id: String) async throws {
    logger.debug("Completing suggestion: \(id)")
    try await supabaseManager.client
      .from("suggestions")
      .update(["status": "completed"])
      .eq("id", value: id)
      .execute()
    logger.info("Suggestion marked as completed")
  }
}
