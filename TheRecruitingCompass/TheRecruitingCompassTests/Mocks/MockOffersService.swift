import Foundation
@testable import TheRecruitingCompass

final class MockOffersService: OffersManaging, @unchecked Sendable {
  var stubbedOffers: [Offer] = []
  var stubbedSchools: [School] = []
  var stubbedCreatedOffer: Offer?
  var shouldThrowFetchError = false
  var shouldThrowCreateError = false
  var shouldThrowDeleteError = false

  var fetchOffersCallCount = 0
  var fetchSchoolsCallCount = 0
  var createOfferCallCount = 0
  var deleteOfferCallCount = 0
  var lastDeletedOfferId: String?
  var lastCreateRequest: OfferCreateRequest?

  func fetchOffers(userId: String) async throws -> [Offer] {
    fetchOffersCallCount += 1
    if shouldThrowFetchError {
      throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
    }
    return stubbedOffers
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    fetchSchoolsCallCount += 1
    return stubbedSchools
  }

  func createOffer(_ request: OfferCreateRequest) async throws -> Offer {
    createOfferCallCount += 1
    lastCreateRequest = request
    if shouldThrowCreateError {
      throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Create failed"])
    }
    return stubbedCreatedOffer ?? makeTestOffer(id: "new-offer")
  }

  func deleteOffer(id: String) async throws {
    deleteOfferCallCount += 1
    lastDeletedOfferId = id
    if shouldThrowDeleteError {
      throw NSError(domain: "MockError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
    }
  }
}
