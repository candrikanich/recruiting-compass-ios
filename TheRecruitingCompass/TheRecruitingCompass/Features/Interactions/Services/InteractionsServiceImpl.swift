import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InteractionsService")

final class InteractionsServiceImpl: InteractionsManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    logger.info("Fetching interactions for family: \(familyUnitId)")

    let interactions: [Interaction] = try await supabaseManager.client
      .from("interactions")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .order("occurred_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(interactions.count) interactions")
    return interactions
  }

  func fetchInteractionsForUser(userId: String) async throws -> [Interaction] {
    logger.info("Fetching interactions for user: \(userId)")

    let interactions: [Interaction] = try await supabaseManager.client
      .from("interactions")
      .select()
      .eq("logged_by", value: userId)
      .order("occurred_at", ascending: false)
      .execute()
      .value

    logger.info("Fetched \(interactions.count) interactions")
    return interactions
  }

  func fetchInteraction(id: String) async throws -> Interaction {
    logger.info("Fetching interaction: \(id)")

    let interaction: Interaction = try await supabaseManager.client
      .from("interactions")
      .select()
      .eq("id", value: id)
      .single()
      .execute()
      .value

    logger.info("Fetched interaction: \(id)")
    return interaction
  }

  func fetchLoggedByUserName(userId: String) async throws -> String {
    logger.info("Fetching user name for: \(userId)")

    struct UserResponse: Codable {
      let fullName: String?

      enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
      }
    }

    let user: UserResponse = try await supabaseManager.client
      .from("users")
      .select("full_name")
      .eq("id", value: userId)
      .single()
      .execute()
      .value

    let name = user.fullName ?? "Unknown"
    logger.info("Fetched user name: \(name)")
    return name
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    logger.info("Fetching schools for family: \(familyUnitId)")

    let schools: [School] = try await supabaseManager.client
      .from("schools")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .execute()
      .value

    logger.info("Fetched \(schools.count) schools")
    return schools
  }

  func fetchCoaches(familyUnitId: String) async throws -> [Coach] {
    logger.info("Fetching all coaches for family: \(familyUnitId)")

    let coaches: [Coach] = try await supabaseManager.client
      .from("coaches")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .order("last_name")
      .execute()
      .value

    logger.info("Fetched \(coaches.count) coaches")
    return coaches
  }

  func createInteraction(_ interaction: InteractionCreateRequest) async throws -> Interaction {
    logger.info("Creating interaction")

    let result: Interaction = try await supabaseManager.client
      .from("interactions")
      .insert(interaction)
      .select()
      .single()
      .execute()
      .value

    logger.info("Created interaction: \(result.id)")
    return result
  }

  func createCoach(_ coach: CoachCreateRequest) async throws -> Coach {
    logger.info("Creating coach: \(coach.firstName) \(coach.lastName)")

    let result: Coach = try await supabaseManager.client
      .from("coaches")
      .insert(coach)
      .select()
      .single()
      .execute()
      .value

    logger.info("Created coach: \(result.id)")
    return result
  }

  func uploadAttachment(interactionId: String, fileName: String, fileData: Data) async throws -> String {
    logger.info("Uploading attachment: \(fileName) for interaction: \(interactionId)")

    let storagePath = "interactions/\(interactionId)/\(fileName)"

    try await supabaseManager.client.storage
      .from("interaction-attachments")
      .upload(
        storagePath,
        data: fileData,
        options: FileOptions(contentType: mimeType(for: fileName))
      )

    logger.info("Uploaded attachment: \(storagePath)")
    return storagePath
  }

  private func mimeType(for fileName: String) -> String {
    let ext = (fileName as NSString).pathExtension.lowercased()
    switch ext {
    case "pdf": return "application/pdf"
    case "jpg", "jpeg": return "image/jpeg"
    case "png": return "image/png"
    case "gif": return "image/gif"
    case "doc": return "application/msword"
    case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    case "txt": return "text/plain"
    default: return "application/octet-stream"
    }
  }

  func deleteInteraction(id: String) async throws {
    logger.info("Deleting interaction: \(id)")

    try await supabaseManager.client
      .from("interactions")
      .delete()
      .eq("id", value: id)
      .execute()

    logger.info("Deleted interaction: \(id)")
  }

  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult {
    logger.info("Cascade deleting interaction: \(id)")

    let result: CascadeDeleteResult = try await supabaseManager.client
      .rpc("cascade_delete_interaction", params: ["interaction_id": id])
      .execute()
      .value

    logger.info("Cascade deleted interaction: \(id)")
    return result
  }
}
