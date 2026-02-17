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
    logger.info("Fetching offers for user: \(userId)")

    let offers: [Offer] = try await supabaseManager.client
      .from("offers")
      .select()
      .eq("user_id", value: userId)
      .order("offer_date", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(offers.count) offers")
    return offers
  }

  func fetchOffer(id: String) async throws -> Offer {
    logger.info("Fetching offer: \(id)")

    let offer: Offer = try await supabaseManager.client
      .from("offers")
      .select()
      .eq("id", value: id)
      .single()
      .execute()
      .value

    logger.info("Fetched offer: \(offer.id)")
    return offer
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

  func fetchSchool(id: String) async throws -> School {
    logger.info("Fetching school: \(id)")

    let school: School = try await supabaseManager.client
      .from("schools")
      .select()
      .eq("id", value: id)
      .single()
      .execute()
      .value

    logger.info("Fetched school: \(school.name)")
    return school
  }

  func createOffer(_ request: OfferCreateRequest) async throws -> Offer {
    logger.info("Creating offer")

    let result: Offer = try await supabaseManager.client
      .from("offers")
      .insert(request)
      .select()
      .single()
      .execute()
      .value

    logger.info("Created offer: \(result.id)")
    return result
  }

  func updateOffer(id: String, data: OfferUpdateRequest) async throws -> Offer {
    logger.info("Updating offer: \(id)")

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
  }

  func deleteOffer(id: String) async throws {
    logger.info("Deleting offer: \(id)")

    try await supabaseManager.client
      .from("offers")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Deleted offer: \(id)")
  }
}
