import Foundation

struct RegenerateFamilyCodeResponse: Codable, Sendable {
  let familyCode: String

  enum CodingKeys: String, CodingKey {
    case familyCode = "familyCode"
  }
}
