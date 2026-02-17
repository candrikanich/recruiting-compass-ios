import Foundation
@testable import TheRecruitingCompass

final class MockOffersService: OffersManaging, @unchecked Sendable {
  var stubbedOffers: [Offer] = []
  var stubbedOffer: Offer?
  var stubbedSchools: [School] = []
  var stubbedSchool: School?
  var stubbedCreatedOffer: Offer?
  var stubbedUpdatedOffer: Offer?
  var shouldThrowFetchError = false
  var shouldThrowFetchOfferError = false
  var shouldThrowFetchSchoolError = false
  var shouldThrowCreateError = false
  var shouldThrowUpdateError = false
  var shouldThrowDeleteError = false

  var fetchOffersCallCount = 0
  var fetchOfferCallCount = 0
  var fetchSchoolsCallCount = 0
  var fetchSchoolCallCount = 0
  var createOfferCallCount = 0
  var updateOfferCallCount = 0
  var deleteOfferCallCount = 0
  var lastDeletedOfferId: String?
  var lastCreateRequest: OfferCreateRequest?
  var lastUpdateRequest: OfferUpdateRequest?
  var lastUpdateId: String?

  func fetchOffers(userId: String) async throws -> [Offer] {
    fetchOffersCallCount += 1
    if shouldThrowFetchError {
      throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
    }
    return stubbedOffers
  }

  func fetchOffer(id: String) async throws -> Offer {
    fetchOfferCallCount += 1
    if shouldThrowFetchOfferError {
      throw NSError(domain: "MockError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Fetch offer failed"])
    }
    return stubbedOffer ?? makeTestOffer(id: id)
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    fetchSchoolsCallCount += 1
    return stubbedSchools
  }

  func fetchSchool(id: String) async throws -> School {
    fetchSchoolCallCount += 1
    if shouldThrowFetchSchoolError {
      throw NSError(domain: "MockError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Fetch school failed"])
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockError", code: 5, userInfo: [NSLocalizedDescriptionKey: "No stubbed school"])
    }
    return school
  }

  func createOffer(_ request: OfferCreateRequest) async throws -> Offer {
    createOfferCallCount += 1
    lastCreateRequest = request
    if shouldThrowCreateError {
      throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Create failed"])
    }
    return stubbedCreatedOffer ?? makeTestOffer(id: "new-offer")
  }

  func updateOffer(id: String, data: OfferUpdateRequest) async throws -> Offer {
    updateOfferCallCount += 1
    lastUpdateId = id
    lastUpdateRequest = data
    if shouldThrowUpdateError {
      throw NSError(domain: "MockError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Update failed"])
    }
    return stubbedUpdatedOffer ?? makeTestOffer(id: id)
  }

  func deleteOffer(id: String) async throws {
    deleteOfferCallCount += 1
    lastDeletedOfferId = id
    if shouldThrowDeleteError {
      throw NSError(domain: "MockError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
    }
  }
}
