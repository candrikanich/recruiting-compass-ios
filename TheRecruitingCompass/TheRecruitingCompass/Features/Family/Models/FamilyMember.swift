import Foundation

struct FamilyMember: Codable, Identifiable, Sendable {
  let id: String
  let userId: String
  let familyUnitId: String
  let role: String
  let addedAt: String?
  let user: FamilyMemberUser?
  /// Server verdict from GET /api/family/members (nil from the direct-Supabase read or older servers: treat as not removable).
  var canRemove: Bool?
  var removeBlockedReason: String?

  var memberRole: UserRole? { UserRole(rawValue: role) }

  var isAthlete: Bool { memberRole == .player }

  var isParent: Bool { memberRole == .parent }

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case role
    case addedAt = "added_at"
    case user
    case canRemove
    case removeBlockedReason
  }
}
