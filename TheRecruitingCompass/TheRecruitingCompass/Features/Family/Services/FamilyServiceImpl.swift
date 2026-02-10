import Foundation
import Supabase

final class FamilyServiceImpl: FamilyManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    let response: [FamilyMember] = try await supabaseManager.client
      .from("family_members")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value
    return response
  }

  func getCurrentMember(userId: String) async throws -> FamilyMember? {
    print("[FamilyService] Fetching family_members for user_id: \(userId)")
    do {
      let response: [FamilyMember] = try await supabaseManager.client
        .from("family_members")
        .select()
        .eq("user_id", value: userId)
        .limit(1)
        .execute()
        .value
      print("[FamilyService] family_members query returned \(response.count) rows")
      if let member = response.first {
        print("[FamilyService] Found member: id=\(member.id), familyUnitId=\(member.familyUnitId), role=\(member.role)")
      }
      return response.first
    } catch {
      print("[FamilyService] family_members query ERROR: \(error)")
      throw error
    }
  }

  func getFamilyUnit(forPlayerUserId userId: String) async throws -> FamilyUnit? {
    print("[FamilyService] Fetching family_units for player_user_id: \(userId)")
    do {
      let response: [FamilyUnit] = try await supabaseManager.client
        .from("family_units")
        .select()
        .eq("player_user_id", value: userId)
        .limit(1)
        .execute()
        .value
      print("[FamilyService] family_units query returned \(response.count) rows")
      if let unit = response.first {
        print("[FamilyService] Found unit: id=\(unit.id), playerUserId=\(unit.playerUserId)")
      }
      return response.first
    } catch {
      print("[FamilyService] family_units query ERROR: \(error)")
      throw error
    }
  }
}
