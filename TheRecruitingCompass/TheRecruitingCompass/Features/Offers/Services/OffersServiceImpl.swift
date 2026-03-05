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
    logger.debug("Fetching offers for user: \(userId, privacy: .private)")
    do {
      let offers: [Offer] = try await supabaseManager.client
        .from("offers")
        .select()
        .eq("user_id", value: userId)
        .order("offer_date", ascending: false)
        .execute()
        .value
      logger.info("Fetched \(offers.count) offers")
      return offers
    } catch {
      logger.error("fetchOffers failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchOffer(id: String) async throws -> Offer {
    logger.debug("Fetching offer: \(id)")
    do {
      let offer: Offer = try await supabaseManager.client
        .from("offers")
        .select()
        .eq("id", value: id)
        .single()
        .execute()
        .value
      logger.info("Fetched offer: \(offer.id)")
      return offer
    } catch {
      logger.error("fetchOffer \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    logger.debug("Fetching schools for family: \(familyUnitId)")
    do {
      let schools: [School] = try await supabaseManager.client
        .from("schools")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .execute()
        .value
      logger.info("Fetched \(schools.count) schools")
      return schools
    } catch {
      logger.error("fetchSchools failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchSchool(id: String) async throws -> School {
    logger.debug("Fetching school: \(id)")
    do {
      let school: School = try await supabaseManager.client
        .from("schools")
        .select()
        .eq("id", value: id)
        .single()
        .execute()
        .value
      logger.info("Fetched school: \(school.name)")
      return school
    } catch {
      logger.error("fetchSchool \(id) failed: \(error.localizedDescription)")
      throw error
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
