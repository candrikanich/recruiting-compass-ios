import Foundation
import Supabase
import OSLog

let familyServiceLogger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyService")

/// Sendable: Stateless service with no mutable properties
final class FamilyServiceImpl: FamilyManaging, Sendable {
  let supabaseManager: SupabaseManager
  private let clientOverride: SupabaseClient?

  /// `client` lets tests point the real queries at a stubbed URLSession.
  init(supabaseManager: SupabaseManager, client: SupabaseClient? = nil) {
    self.supabaseManager = supabaseManager
    self.clientOverride = client
  }

  var database: SupabaseClient { clientOverride ?? supabaseManager.client }

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

  func getMemberships(userId: String) async throws -> [FamilyMember] {
    familyServiceLogger.debug("Fetching memberships for user: \(userId, privacy: .private)")
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

    // Most recently joined first, the same order as web's `getCallerFamilyUnitIds`.
    let rows: [FamilyMemberRow] = try await database
      .from("family_members")
      .select("id, user_id, family_unit_id, role, added_at")
      .eq("user_id", value: userId)
      .order("added_at", ascending: false)
      .execute()
      .value

    let users: [FamilyMemberUser] = try await database
      .from("users")
      .select("id, email, full_name, role")
      .eq("id", value: userId)
      .limit(1)
      .execute()
      .value

    return rows.map {
      FamilyMember(
        id: $0.id,
        userId: $0.userId,
        familyUnitId: $0.familyUnitId,
        role: $0.role,
        addedAt: $0.addedAt,
        user: users.first
      )
    }
  }

  func familyPlayers(among familyUnitIds: [String]) async throws -> [FamilyPlayer] {
    struct Row: Codable {
      let familyUnitId: String
      let users: Graduation
      struct Graduation: Codable {
        let graduationYear: Int?
        enum CodingKeys: String, CodingKey { case graduationYear = "graduation_year" }
      }
      enum CodingKeys: String, CodingKey {
        case familyUnitId = "family_unit_id"
        case users
      }
    }
    let rows: [Row] = try await database.from("family_members")
      .select("family_unit_id, users!inner(graduation_year)")
      .in("family_unit_id", values: familyUnitIds)
      .eq("role", value: "player")
      .execute()
      .value
    return rows.map { FamilyPlayer(familyUnitId: $0.familyUnitId, graduationYear: $0.users.graduationYear) }
  }

  func getFamilyUnit(id: String) async throws -> FamilyUnit? {
    let units: [FamilyUnit] = try await database
      .from("family_units")
      .select()
      .eq("id", value: id)
      .limit(1)
      .execute()
      .value
    return units.first
  }

  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit? {
    guard let membership = try await getMemberships(userId: userId).first else {
      familyServiceLogger.debug("No family unit found for user: \(userId, privacy: .private)")
      return nil
    }
    return try await getFamilyUnit(id: membership.familyUnitId)
  }
}
