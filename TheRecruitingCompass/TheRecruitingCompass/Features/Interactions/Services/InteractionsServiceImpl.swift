import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InteractionsService")

final class InteractionsServiceImpl: InteractionsManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    logger.info("Fetching interactions for family: \(familyUnitId)")

    let interactions: [Interaction] = try await supabaseManager.client
      .from("interactions")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .order("occurred_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(interactions.count) interactions")
    return interactions
  }

  func fetchInteractionsForUser(userId: String) async throws -> [Interaction] {
    logger.info("Fetching interactions for user: \(userId)")

    let interactions: [Interaction] = try await supabaseManager.client
      .from("interactions")
      .select()
      .eq("logged_by", value: userId)
      .order("occurred_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(interactions.count) interactions")
    return interactions
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    logger.info("Fetching schools for family: \(familyUnitId)")

    let schools: [School] = try await supabaseManager.client
      .from("schools")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value

    logger.info("Fetched \(schools.count) schools")
    return schools
  }

  func fetchCoaches(schoolIds: [String]) async throws -> [Coach] {
    guard !schoolIds.isEmpty else { return [] }

    logger.info("Fetching coaches for \(schoolIds.count) schools")

    let coaches: [Coach] = try await supabaseManager.client
      .from("coaches")
      .select()
      .in("school_id", values: schoolIds)
      .execute()
      .value

    logger.info("Fetched \(coaches.count) coaches")
    return coaches
  }

  func deleteInteraction(id: String) async throws {
    logger.info("Deleting interaction: \(id)")

    try await supabaseManager.client
      .from("interactions")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Deleted interaction: \(id)")
  }

  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult {
    logger.info("Cascade deleting interaction: \(id)")

    let result: CascadeDeleteResult = try await supabaseManager.client
      .rpc("cascade_delete_interaction", params: ["interaction_id": id])
      .execute()
      .value

    logger.info("Cascade deleted interaction: \(id)")
    return result
  }
}
