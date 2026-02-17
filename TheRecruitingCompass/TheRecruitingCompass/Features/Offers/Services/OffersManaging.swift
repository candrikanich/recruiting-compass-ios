import Foundation

protocol OffersManaging: Sendable {
  func fetchOffers(userId: String) async throws -> [Offer]
  func fetchOffer(id: String) async throws -> Offer
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func fetchSchool(id: String) async throws -> School
  func createOffer(_ request: OfferCreateRequest) async throws -> Offer
  func updateOffer(id: String, data: OfferUpdateRequest) async throws -> Offer
  func deleteOffer(id: String) async throws
}
