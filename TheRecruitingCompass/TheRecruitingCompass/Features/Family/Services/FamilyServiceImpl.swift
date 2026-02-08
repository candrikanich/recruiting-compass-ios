import Foundation
import Supabase

final class FamilyServiceImpl: FamilyManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  @MainActor
  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    let response: [FamilyMember] = try await supabaseManager.client
      .from("family_members")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value
    return response
  }

  @MainActor
  func getCurrentMember(userId: String) async throws -> FamilyMember? {
    let response: [FamilyMember] = try await supabaseManager.client
      .from("family_members")
      .select()
      .eq("user_id", value: userId)
      .limit(1)
      .execute()
      .value
    return response.first
  }
}
