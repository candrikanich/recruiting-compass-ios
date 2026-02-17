import Foundation

protocol OffersManaging: Sendable {
  func fetchOffers(userId: String) async throws -> [Offer]
  func fetchSchools(familyUnitId: String) async throws -> [School]
  func createOffer(_ request: OfferCreateRequest) async throws -> Offer
  func deleteOffer(id: String) async throws
}
