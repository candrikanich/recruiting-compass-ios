import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("SchoolsInsertPayload — what createSchool actually sends")
struct SchoolsInsertPayloadTests {

  private func encoded(isFavorite: Bool?) throws -> [String: Any] {
    let request = try SchoolCreateRequest(
      userId: "user-1", familyUnitId: "family-1", name: "Ohio State University",
      location: nil, city: nil, state: nil, division: nil, conference: nil, website: nil,
      twitterHandle: nil, instagramHandle: nil, ncaaId: nil, notes: nil, status: "researching",
      academicInfo: nil, faviconUrl: nil, isFavorite: isFavorite
    )
    let data = try JSONEncoder().encode(SchoolsInsertPayload(from: request))
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  @Test func aFavoritePickSendsIsFavoriteTrue() throws {
    #expect(try encoded(isFavorite: true)["is_favorite"] as? Bool == true)
  }

  @Test func anOrdinaryCreateOmitsTheKeyEntirely() throws {
    #expect(try encoded(isFavorite: nil).keys.contains("is_favorite") == false)
  }
}
