import Foundation
import Supabase
import OSLog

extension FamilyServiceImpl {
  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws {
    familyServiceLogger.debug("Saving player details for family: \(familyId, privacy: .private)")
    do {
      guard try await apiClient.savePlayerDetails(familyId: familyId, details: details) == .endpointUnavailable
      else {
        familyServiceLogger.info("Player details saved via API for family: \(familyId, privacy: .private)")
        return
      }
    } catch {
      familyServiceLogger.error("savePlayerDetails API failed: \(error.localizedDescription)")
      throw error
    }
    // TODO(#369): remove once every server (prod included) serves /api/family/player-details.
    familyServiceLogger.notice("player-details endpoint missing (older server); using direct write")
    try await saveViaDirectWrite(familyId: familyId, details: details)
  }

  private func saveViaDirectWrite(familyId: String, details: PendingPlayerDetails) async throws {
    struct UpdatePayload: Encodable {
      let pendingPlayerDetails: PendingPlayerDetails

      enum CodingKeys: String, CodingKey {
        case pendingPlayerDetails = "pending_player_details"
      }
    }
    do {
      try await supabaseManager.client
        .from("family_units")
        .update(UpdatePayload(pendingPlayerDetails: details))
        .eq("id", value: familyId)
        .execute()
      familyServiceLogger.info("Player details saved for family: \(familyId, privacy: .private)")
    } catch {
      familyServiceLogger.error("savePlayerDetails failed: \(error.localizedDescription)")
      throw error
    }
  }

  func getParentFamilies() async throws -> [ParentFamilyData] {
    familyServiceLogger.debug("Fetching parent families")
    guard let userId = try await supabaseManager.client.auth.session.user.id.uuidString as String? else {
      throw FamilyError.notAuthenticated
    }

    do {
      let memberships: [ParentFamilyMembership] = try await supabaseManager.client
        .from("family_members")
        .select("family_unit_id, family_units!inner(id, family_code, family_name, code_generated_at)")
        .eq("user_id", value: userId)
        .eq("role", value: "parent")
        .execute()
        .value

      let families = memberships.map { membership in
        let fu = membership.familyUnit
        return ParentFamilyData(
          familyId: fu.id,
          familyCode: fu.familyCode ?? "",
          familyName: fu.familyName ?? "My Family",
          codeGeneratedAt: fu.codeGeneratedAt ?? ""
        )
      }
      familyServiceLogger.info("Fetched \(families.count) parent families")
      return families
    } catch {
      familyServiceLogger.error("getParentFamilies failed: \(error.localizedDescription)")
      throw error
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
    let familyCode: String?
    let familyName: String?
    let codeGeneratedAt: String?

    enum CodingKeys: String, CodingKey {
      case id
      case familyCode = "family_code"
      case familyName = "family_name"
      case codeGeneratedAt = "code_generated_at"
    }
  }
}
