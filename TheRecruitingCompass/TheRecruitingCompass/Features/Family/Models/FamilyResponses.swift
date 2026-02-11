import Foundation

struct CreateFamilyResponse: Codable, Sendable {
  let success: Bool
  let familyCode: String
  let familyId: String
  let familyName: String

  enum CodingKeys: String, CodingKey {
    case success
    case familyCode = "familyCode"
    case familyId = "familyId"
    case familyName = "familyName"
  }
}

struct RegenerateFamilyCodeResponse: Codable, Sendable {
  let familyCode: String

  enum CodingKeys: String, CodingKey {
    case familyCode = "familyCode"
  }
}
