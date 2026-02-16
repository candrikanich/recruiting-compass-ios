import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CoachesService")

/// Sendable: Stateless service with no mutable properties
final class CoachesServiceImpl: CoachesManaging, Sendable {
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
        .order("last_name")
        .execute()
        .value
    }
  }

  func createCoach(request: CoachCreateRequest) async throws -> Coach {
    logger.debug("Creating coach: \(request.firstName) \(request.lastName)")

    let result: Coach = try await supabaseManager.client
      .from("coaches")
      .insert(request)
      .select()
      .single()
      .execute()
      .value

    logger.info("Coach created: \(result.id)")
    return result
  }

  func deleteCoach(id: String) async throws {
    logger.debug("Deleting coach: \(id)")
    try await supabaseManager.client
      .from("coaches")
      .delete()
      .eq("id", value: id)
      .execute()
    logger.info("Coach deleted: \(id)")
  }

  func cascadeDeleteCoach(id: String) async throws -> DeleteResult {
    logger.debug("Cascade deleting coach: \(id)")
    let result: DeleteResult = try await supabaseManager.client
      .rpc("cascade_delete_coach", params: ["coach_id": id])
      .execute()
      .value
    logger.info("Cascade delete complete for coach: \(id)")
    return result
  }

  func updateCoach(id: String, updates: CoachUpdateRequest) async throws -> Coach {
    logger.debug("Updating coach: \(id)")

    let result: Coach = try await supabaseManager.client
      .from("coaches")
      .update(updates)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Coach updated: \(id)")
    return result
  }

  func fetchInteractions(coachId: String, limit: Int) async throws -> [Interaction] {
    try await fetch("interactions for coach \(coachId)") {
      try await supabaseManager.client
        .from("interactions")
        .select()
        .eq("coach_id", value: coachId)
        .order("occurred_at", ascending: false)
        .limit(limit)
        .execute()
        .value
    }
  }
}
