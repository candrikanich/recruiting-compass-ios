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

  func fetchSchool(id: String, familyUnitId: String) async throws -> School {
    logger.debug("Fetching single school: \(id)")
    do {
      let school: School = try await supabaseManager.client
        .from("schools")
        .select()
        .eq("id", value: id)
        .eq("family_unit_id", value: familyUnitId)
        .single()
        .execute()
        .value
      logger.info("Fetched school: \(school.name)")
      return school
    } catch {
      logger.error("Failed to fetch school: \(error.localizedDescription)")
      throw error
    }
  }

  func updateStatus(
    id: String,
    newStatus: SchoolStatus,
    previousStatus: SchoolStatus,
    userId: String
  ) async throws -> School {
    logger.debug("Updating school status: \(id) from \(previousStatus.rawValue) to \(newStatus.rawValue)")

    let now = Date()
    let iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // 1. Update school status
    let updatedSchool: School = try await supabaseManager.client
      .from("schools")
      .update([
        "status": newStatus.rawValue,
        "status_changed_at": iso8601Formatter.string(from: now),
        "updated_by": userId
      ])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    // 2. Create history entry
    try await supabaseManager.client
      .from("school_status_history")
      .insert([
        "school_id": id,
        "previous_status": previousStatus.rawValue,
        "new_status": newStatus.rawValue,
        "changed_by": userId,
        "changed_at": iso8601Formatter.string(from: now)
      ])
      .execute()

    logger.info("School status updated and history created for: \(id)")
    return updatedSchool
  }

  func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory] {
    try await fetch("status history") {
      try await supabaseManager.client
        .from("school_status_history")
        .select()
        .eq("school_id", value: schoolId)
        .order("changed_at", ascending: false)
        .execute()
        .value
    }
  }
}
