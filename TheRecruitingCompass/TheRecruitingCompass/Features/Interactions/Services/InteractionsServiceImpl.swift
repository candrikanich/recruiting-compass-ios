import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InteractionsService")

/// Sendable: Stateless service with no mutable properties
final class InteractionsServiceImpl: InteractionsManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    try await logger.fetch("interactions") {
      try await supabaseManager.client
        .from("interactions")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .order("occurred_at", ascending: false)
        .execute()
        .value
    }
  }

  func fetchInteractionsForUser(userId: String) async throws -> [Interaction] {
    try await logger.fetch("interactions for user") {
      try await supabaseManager.client
        .from("interactions")
        .select()
        .eq("logged_by", value: userId)
        .order("occurred_at", ascending: false)
        .execute()
        .value
    }
  }

  func fetchInteraction(id: String) async throws -> Interaction {
    try await logger.fetchOne("interaction \(id)") {
      try await supabaseManager.client
        .from("interactions")
        .select()
        .eq("id", value: id)
        .single()
        .execute()
        .value
    }
  }

  func fetchLoggedByUserName(userId: String) async throws -> String {
    logger.debug("Fetching user name for: \(userId, privacy: .private)")

    struct UserResponse: Codable {
      let fullName: String?

      enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
      }
    }

    do {
      let user: UserResponse = try await supabaseManager.client
        .from("users")
        .select("full_name")
        .eq("id", value: userId)
        .single()
        .execute()
        .value
      let name = user.fullName ?? "Unknown"
      logger.info("Fetched user name for: \(userId, privacy: .private)")
      return name
    } catch {
      logger.error("fetchLoggedByUserName failed: \(error.localizedDescription)")
      throw error
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await logger.fetch("schools") {
      try await FamilyScopedQueries.fetchSchools(from: supabaseManager.client, familyUnitId: familyUnitId)
    }
  }

  func fetchCoaches(familyUnitId: String) async throws -> [Coach] {
    try await logger.fetch("coaches") {
      try await supabaseManager.client
        .from("coaches")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .order("last_name")
        .execute()
        .value
    }
  }

  func createInteraction(_ interaction: InteractionCreateRequest) async throws -> Interaction {
    logger.debug("Creating interaction")
    do {
      let result: Interaction = try await supabaseManager.client
        .from("interactions")
        .insert(interaction)
        .select()
        .single()
        .execute()
        .value
      logger.info("Created interaction: \(result.id)")
      return result
    } catch {
      logger.error("createInteraction failed: \(error.localizedDescription)")
      throw error
    }
  }

  func createCoach(_ coach: CoachCreateRequest) async throws -> Coach {
    logger.debug("Creating coach: \(coach.firstName) \(coach.lastName)")
    do {
      let result: Coach = try await supabaseManager.client
        .from("coaches")
        .insert(coach)
        .select()
        .single()
        .execute()
        .value
      logger.info("Created coach: \(result.id)")
      return result
    } catch {
      logger.error("createCoach failed: \(error.localizedDescription)")
      throw error
    }
  }

  func uploadAttachment(interactionId: String, fileName: String, fileData: Data) async throws -> String {
    logger.debug("Uploading attachment: \(fileName) for interaction: \(interactionId)")

    let storagePath = "interactions/\(interactionId)/\(fileName)"
    do {
      try await supabaseManager.client.storage
        .from("interaction-attachments")
        .upload(
          storagePath,
          data: fileData,
          options: FileOptions(contentType: mimeType(for: fileName))
        )
      logger.info("Uploaded attachment: \(storagePath)")
      return storagePath
    } catch {
      logger.error("uploadAttachment failed for \(fileName): \(error.localizedDescription)")
      throw error
    }
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
    logger.debug("Deleting interaction: \(id)")
    do {
      try await supabaseManager.client
        .from("interactions")
        .delete()
        .eq("id", value: id)
        .execute()
      logger.info("Deleted interaction: \(id)")
    } catch {
      logger.error("deleteInteraction \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }

  func cascadeDeleteInteraction(id: String) async throws -> CascadeDeleteResult {
    logger.debug("Cascade deleting interaction: \(id)")
    do {
      let result: CascadeDeleteResult = try await supabaseManager.client
        .rpc("cascade_delete_interaction", params: ["interaction_id": id])
        .execute()
        .value
      logger.info("Cascade deleted interaction: \(id)")
      return result
    } catch {
      logger.error("cascadeDeleteInteraction \(id) failed: \(error.localizedDescription)")
      throw error
    }
  }
}
