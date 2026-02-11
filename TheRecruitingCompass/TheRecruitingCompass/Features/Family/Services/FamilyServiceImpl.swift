import Foundation
import Supabase

final class FamilyServiceImpl: FamilyManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  // MARK: - Existing Methods

  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    let response: [FamilyMember] = try await supabaseManager.client
      .from("family_members")
      .select("*, user:users!inner(*)")
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value
    return response
  }

  func getCurrentMember(userId: String) async throws -> FamilyMember? {
    let response: [FamilyMember] = try await supabaseManager.client
      .from("family_members")
      .select("*, user:users!inner(*)")
      .eq("user_id", value: userId)
      .limit(1)
      .execute()
      .value
    return response.first
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
