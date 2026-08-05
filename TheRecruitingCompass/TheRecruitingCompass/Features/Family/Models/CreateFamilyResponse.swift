import Foundation

struct CreateFamilyResponse: Codable, Sendable {
  let success: Bool
  let familyCode: String
  let familyId: String
  /// Omitted when "Family already exists" (web API returns message instead).
  let familyName: String?

  enum CodingKeys: String, CodingKey {
    case success
    case familyCode = "familyCode"
    case familyId = "familyId"
    case familyName = "familyName"
  }
}
