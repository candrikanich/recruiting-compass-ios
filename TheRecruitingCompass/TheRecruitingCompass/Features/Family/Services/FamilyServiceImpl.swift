import Foundation
import Supabase
import OSLog

let familyServiceLogger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyService")

/// Sendable: Stateless service with no mutable properties
final class FamilyServiceImpl: FamilyManaging, Sendable {
  let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  // MARK: - Membership Queries

  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    familyServiceLogger.debug("Fetching family members for family unit: \(familyUnitId)")

    // IMPORTANT: Fetch family_members and users separately to avoid join issues
    // RLS policies allow users to see all members in their families
    struct FamilyMemberRow: Codable {
      let id: String
      let userId: String
      let familyUnitId: String
      let role: String
      let addedAt: String?

      enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
        case role
        case addedAt = "added_at"
      }
    }

    // Step 1: Fetch family_members (RLS allows seeing all members in your family)
    let memberRows: [FamilyMemberRow] = try await supabaseManager.client
      .from("family_members")
      .select("id, user_id, family_unit_id, role, added_at")
      .eq("family_unit_id", value: familyUnitId)
      .order("added_at")
      .execute()
      .value

    familyServiceLogger.debug("Fetched \(memberRows.count) family member rows")

    guard !memberRows.isEmpty else {
      return []
    }

    // Step 2: Fetch user details (RLS allows seeing profiles of family members)
    let userIds = memberRows.map { $0.userId }
    familyServiceLogger.debug("Fetching user details for \(userIds.count) user IDs")

    let users: [FamilyMemberUser] = try await supabaseManager.client
      .from("users")
      .select("id, email, full_name, role")
      .in("id", values: userIds)
      .execute()
      .value

    familyServiceLogger.debug("Fetched \(users.count) user records")

    // Step 3: Combine family_members with user data
    let usersMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    let members = memberRows.map { row in
      FamilyMember(
        id: row.id,
        userId: row.userId,
        familyUnitId: row.familyUnitId,
        role: row.role,
        addedAt: row.addedAt,
        user: usersMap[row.userId]
      )
    }

    familyServiceLogger.debug("Returning \(members.count) family members with user details")
    for member in members {
      familyServiceLogger.debug("Member: id=\(member.id, privacy: .private), role=\(member.role), userId=\(member.userId, privacy: .private), userName=\(member.user?.fullName ?? "nil", privacy: .private)")
    }

    return members
  }

  func getCurrentMember(userId: String) async throws -> FamilyMember? {
    familyServiceLogger.debug("Fetching current member for user: \(userId, privacy: .private)")
    // Fetch family_member record
    struct FamilyMemberRow: Codable {
      let id: String
      let userId: String
      let familyUnitId: String
      let role: String
      let addedAt: String?

      enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
        case role
        case addedAt = "added_at"
      }
    }

    let memberRows: [FamilyMemberRow] = try await supabaseManager.client
      .from("family_members")
      .select("id, user_id, family_unit_id, role, added_at")
      .eq("user_id", value: userId)
      .limit(1)
      .execute()
      .value

    guard let row = memberRows.first else {
      return nil
    }

    // Fetch user details
    let users: [FamilyMemberUser] = try await supabaseManager.client
      .from("users")
      .select("id, email, full_name, role")
      .eq("id", value: userId)
      .limit(1)
      .execute()
      .value

    let member = FamilyMember(
      id: row.id,
      userId: row.userId,
      familyUnitId: row.familyUnitId,
      role: row.role,
      addedAt: row.addedAt,
      user: users.first
    )
    familyServiceLogger.debug("Current member fetched: \(member.id, privacy: .private) role=\(member.role)")
    return member
  }

  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit? {
    familyServiceLogger.debug("Fetching family unit for user: \(userId, privacy: .private)")
    struct MemberRow: Codable {
      let familyUnitId: String
      enum CodingKeys: String, CodingKey {
        case familyUnitId = "family_unit_id"
      }
    }
    let rows: [MemberRow] = try await supabaseManager.client
      .from("family_members")
      .select("family_unit_id")
      .eq("user_id", value: userId)
      .limit(1)
      .execute()
      .value

    guard let row = rows.first else {
      familyServiceLogger.debug("No family unit found for user: \(userId, privacy: .private)")
      return nil
    }

    let units: [FamilyUnit] = try await supabaseManager.client
      .from("family_units")
      .select()
      .eq("id", value: row.familyUnitId)
      .limit(1)
      .execute()
      .value

    if let unit = units.first {
      familyServiceLogger.debug("Fetched family unit: \(unit.id, privacy: .private)")
    }
    return units.first
  }
}
