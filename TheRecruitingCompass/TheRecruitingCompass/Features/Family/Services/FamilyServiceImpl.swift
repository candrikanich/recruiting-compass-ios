import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyService")

final class FamilyServiceImpl: FamilyManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  // MARK: - Existing Methods

  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    print("🔍 [FamilyService] fetchFamilyMembers called for familyUnitId: \(familyUnitId)")
    logger.debug("Fetching family members for family unit: \(familyUnitId)")

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

    logger.debug("Fetched \(memberRows.count) family member rows")

    guard !memberRows.isEmpty else {
      return []
    }

    // Step 2: Fetch user details (RLS allows seeing profiles of family members)
    let userIds = memberRows.map { $0.userId }
    logger.debug("Fetching user details for \(userIds.count) user IDs")

    let users: [FamilyMemberUser] = try await supabaseManager.client
      .from("users")
      .select("id, email, full_name, role")
      .in("id", values: userIds)
      .execute()
      .value

    logger.debug("Fetched \(users.count) user records")

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

    logger.debug("Returning \(members.count) family members with user details")
    for member in members {
      logger.debug("Member: id=\(member.id), role=\(member.role), userId=\(member.userId), userName=\(member.user?.fullName ?? "nil")")
    }

    return members
  }

  func getCurrentMember(userId: String) async throws -> FamilyMember? {
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

    return FamilyMember(
      id: row.id,
      userId: row.userId,
      familyUnitId: row.familyUnitId,
      role: row.role,
      addedAt: row.addedAt,
      user: users.first
    )
  }

  func getFamilyUnit(forPlayerUserId userId: String) async throws -> FamilyUnit? {
    let response: [FamilyUnit] = try await supabaseManager.client
      .from("family_units")
      .select()
      .eq("player_user_id", value: userId)
      .limit(1)
      .execute()
      .value
    return response.first
  }

  // MARK: - Family Management (Player)

  func createFamily() async throws -> CreateFamilyResponse {
    struct EmptyBody: Encodable {}
    let response: CreateFamilyResponse = try await supabaseManager.client.functions
      .invoke("family-create", options: FunctionInvokeOptions(body: EmptyBody()))
    return response
  }

  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse {
    struct RegenerateBody: Encodable {
      let familyId: String
    }
    let response: RegenerateFamilyCodeResponse = try await supabaseManager.client.functions
      .invoke("family-code-regenerate", options: FunctionInvokeOptions(body: RegenerateBody(familyId: familyId)))
    return response
  }

  func removeFamilyMember(memberId: String) async throws {
    struct RemoveResponse: Codable {
      let success: Bool
    }
    let _: RemoveResponse = try await supabaseManager.client.functions
      .invoke("family-members-remove/\(memberId)", options: FunctionInvokeOptions(method: .delete))
  }

  // MARK: - Family Management (Parent)

  func joinFamilyWithCode(familyCode: String) async throws {
    struct JoinBody: Encodable {
      let familyCode: String
    }
    struct JoinResponse: Codable {
      let message: String
    }
    let _: JoinResponse = try await supabaseManager.client.functions
      .invoke("family-code-join", options: FunctionInvokeOptions(body: JoinBody(familyCode: familyCode)))
  }

  func getParentFamilies() async throws -> [ParentFamilyData] {
    guard let userId = try await supabaseManager.client.auth.session.user.id.uuidString as String? else {
      throw FamilyError.notAuthenticated
    }

    let memberships: [ParentFamilyMembership] = try await supabaseManager.client
      .from("family_members")
      .select("family_unit_id, family_units!inner(id, family_code, family_name, code_generated_at)")
      .eq("user_id", value: userId)
      .eq("role", value: "parent")
      .execute()
      .value

    return memberships.map { membership in
      ParentFamilyData(
        familyId: membership.familyUnit.id,
        familyCode: membership.familyUnit.familyCode,
        familyName: membership.familyUnit.familyName,
        codeGeneratedAt: membership.familyUnit.codeGeneratedAt
      )
    }
  }
}

// MARK: - Internal Types

private struct ParentFamilyMembership: Codable {
  let familyUnitId: String
  let familyUnit: FamilyUnitData

  enum CodingKeys: String, CodingKey {
    case familyUnitId = "family_unit_id"
    case familyUnit = "family_units"
  }

  struct FamilyUnitData: Codable {
    let id: String
    let familyCode: String
    let familyName: String
    let codeGeneratedAt: String

    enum CodingKeys: String, CodingKey {
      case id
      case familyCode = "family_code"
      case familyName = "family_name"
      case codeGeneratedAt = "code_generated_at"
    }
  }
}
