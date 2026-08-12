import Foundation

/// Service contract for scholarship offer CRUD operations.
protocol OffersManaging: Sendable {
  /// Returns all offers received by the given user.
  func fetchOffers(userId: String) async throws -> [Offer]
  /// Returns a single offer by ID.
  func fetchOffer(id: String) async throws -> Offer
  /// Returns all schools for the family unit (used to populate school pickers in the offer form).
  func fetchSchools(familyUnitId: String) async throws -> [School]
  /// Returns a single school by ID (used to resolve the school name in offer detail).
  func fetchSchool(id: String) async throws -> School
  /// Creates a new offer record and returns the persisted entity.
  func createOffer(_ request: OfferCreateRequest) async throws -> Offer
  /// Applies partial updates to an existing offer and returns the updated entity.
  func updateOffer(id: String, data: OfferUpdateRequest) async throws -> Offer
  /// Permanently deletes an offer.
  func deleteOffer(id: String) async throws
}
