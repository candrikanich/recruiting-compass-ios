import Foundation

struct FamilyMember: Codable, Identifiable, Sendable {
  let id: String
  let userId: String
  let familyUnitId: String
  let role: String
  let addedAt: String?
  let user: FamilyMemberUser?

  var isAthlete: Bool {
    role == "athlete"
  }

  var isParent: Bool {
    role == "parent"
  }

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case role
    case addedAt = "added_at"
    case user
  }
}
