import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OffersService")

final class OffersServiceImpl: OffersManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchOffers(userId: String) async throws -> [Offer] {
    try await logger.fetch("offers") {
      try await supabaseManager.client
        .from("offers")
        .select()
        .eq("user_id", value: userId)
        .order("offer_date", ascending: false)
        .execute()
        .value
    }
  }

  func fetchOffer(id: String) async throws -> Offer {
    try await logger.fetchOne("offer \(id)") {
      try await supabaseManager.client
        .from("offers")
        .select()
        .eq("id", value: id)
        .single()
        .execute()
        .value
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await logger.fetch("schools") {
      try await FamilyScopedQueries.fetchSchools(from: supabaseManager.client, familyUnitId: familyUnitId)
    }
  }

  func fetchSchool(id: String) async throws -> School {
    try await logger.fetchOne("school \(id)") {
      try await FamilyScopedQueries.fetchSchool(from: supabaseManager.client, id: id)
    }
  }

  func createOffer(_ request: OfferCreateRequest) async throws -> Offer {
    logger.debug("Creating offer")
    do {
      let result: Offer = try await supabaseManager.client
        .from("offers")
        .insert(request)
        .select()
        .single()
        .execute()
        .value
      logger.info("Created offer: \(result.id)")
      return result
    } catch {
      logger.error("createOffer failed: \(error.localizedDescription)")
      throw error
    }
  }

  func updateOffer(id: String, data: OfferUpdateRequest) async throws -> Offer {
    logger.debug("Updating offer: \(id)")
    do {
      let result: Offer = try await supabaseManager.client
        .from("offers")
        .update(data)
        .eq("id", value: id)
        .select()
        .single()
        .execute()
        .value
      logger.info("Updated offer: \(result.id)")
      return result
    } catch {
      logger.error("updateOffer \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func deleteOffer(id: String) async throws {
    logger.debug("Deleting offer: \(id)")
    do {
      try await supabaseManager.client
        .from("offers")
        .delete()
        .eq("id", value: id)
        .execute()
      logger.info("Deleted offer: \(id)")
    } catch {
      logger.error("deleteOffer \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }
}
