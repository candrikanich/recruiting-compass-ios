import Foundation

/// GET /api/family/members?familyId=… — members plus the server's verdict on what the caller may do.
/// Every rule field is optional: iOS never recomputes membership rules, and older servers omit them.
struct FamilyMembersDetail: Decodable, Sendable {
  let members: [FamilyMember]
  let ownerUserId: String?
  let canLeave: Bool?
  let leaveBlockedReason: String?

  private struct Wire: Decodable {
    let id: String
    let userId: String
    let familyUnitId: String
    let role: String
    let addedAt: String?
    let users: FamilyMemberUser?
    let canRemove: Bool?
    let removeBlockedReason: String?

    enum CodingKeys: String, CodingKey {
      case id, role, users, canRemove, removeBlockedReason
      case userId = "user_id"
      case familyUnitId = "family_unit_id"
      case addedAt = "added_at"
    }
  }

  private struct Permissions: Decodable {
    let canLeave: Bool?
  }

  enum CodingKeys: String, CodingKey {
    case members, ownerUserId, permissions, leaveBlockedReason
  }

  init(
    members: [FamilyMember], ownerUserId: String? = nil, canLeave: Bool? = nil, leaveBlockedReason: String? = nil
  ) {
    self.members = members
    self.ownerUserId = ownerUserId
    self.canLeave = canLeave
    self.leaveBlockedReason = leaveBlockedReason
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    members = try c.decode([Wire].self, forKey: .members).map {
      FamilyMember(
        id: $0.id, userId: $0.userId, familyUnitId: $0.familyUnitId, role: $0.role, addedAt: $0.addedAt,
        user: $0.users, canRemove: $0.canRemove, removeBlockedReason: $0.removeBlockedReason
      )
    }
    ownerUserId = try c.decodeIfPresent(String.self, forKey: .ownerUserId)
    canLeave = try c.decodeIfPresent(Permissions.self, forKey: .permissions)?.canLeave
    leaveBlockedReason = try c.decodeIfPresent(String.self, forKey: .leaveBlockedReason)
  }
}

/// POST /api/family/leave result.
enum FamilyLeaveOutcome: String, Decodable, Sendable {
  case left
  case familyDeleted = "family_deleted"
}
