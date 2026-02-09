import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolsService")

final class SchoolsServiceImpl: SchoolsManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  private func fetch<T: Decodable>(
    _ label: String,
    query: () async throws -> [T]
  ) async throws -> [T] {
    logger.debug("Fetching \(label)")
    do {
      let result = try await query()
      logger.info("Fetched \(result.count) \(label)")
      return result
    } catch {
      logger.error("Failed to fetch \(label): \(error.localizedDescription)")
      if let decodingError = error as? DecodingError {
        logger.error("Decoding error: \(String(describing: decodingError))")
      }
      throw error
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await fetch("schools") {
      try await supabaseManager.client
        .from("schools")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .order("name")
        .execute()
        .value
    }
  }

  func deleteSchool(id: String) async throws {
    logger.debug("Deleting school: \(id)")
    try await supabaseManager.client
      .from("schools")
      .delete()
      .eq("id", value: id)
      .execute()
    logger.info("School deleted: \(id)")
  }

  func cascadeDeleteSchool(id: String) async throws -> DeleteResult {
    logger.debug("Cascade deleting school: \(id)")
    let result: DeleteResult = try await supabaseManager.client
      .rpc("cascade_delete_school", params: ["school_id": id])
      .execute()
      .value
    logger.info("Cascade delete complete for school: \(id)")
    return result
  }

  func toggleFavorite(id: String, isFavorite: Bool) async throws {
    logger.debug("Toggling favorite for school: \(id) to \(isFavorite)")
    try await supabaseManager.client
      .from("schools")
      .update(["is_favorite": isFavorite])
      .eq("id", value: id)
      .execute()
    logger.info("School favorite toggled: \(id)")
  }
}
