import Foundation

struct ParentFamilyData: Codable, Identifiable, Sendable {
  var id: String { familyId }
  let familyId: String
  let familyCode: String
  let familyName: String
  /// Filled from the inbound-address endpoint; this model is read straight from Supabase, which has no label.
  var familyLabel: String?
  let codeGeneratedAt: String
  var members: [FamilyMember] = []

  var displayLabel: String { FamilyLabel.display(label: familyLabel, legacyName: familyName) ?? familyName }

  enum CodingKeys: String, CodingKey {
    case familyId = "family_id"
    case familyCode = "family_code"
    case familyName = "family_name"
    case familyLabel = "family_label"
    case codeGeneratedAt = "code_generated_at"
  }
}
