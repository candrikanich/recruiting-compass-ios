import Foundation

struct ParentFamilyData: Codable, Identifiable, Sendable {
  var id: String { familyId }
  let familyId: String
  let familyCode: String
  let familyName: String
  let codeGeneratedAt: String

  enum CodingKeys: String, CodingKey {
    case familyId = "family_id"
    case familyCode = "family_code"
    case familyName = "family_name"
    case codeGeneratedAt = "code_generated_at"
  }
}
