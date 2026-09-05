import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DeadlinesService")

private struct DeadlineInsertPayload: Encodable {
  let userId: String
  let familyUnitId: String
  let label: String
  let deadlineDate: String
  let category: String
  let schoolId: String?

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case label
    case deadlineDate = "deadline_date"
    case category
    case schoolId = "school_id"
  }
}

/// Direct-Supabase-query service for `user_deadlines`, following the
/// VideoLinks/Events pattern. RLS is family-scoped (migration
/// `20260902000000_family_shared_user_deadlines.sql`), so reads/deletes are
/// scoped by `family_unit_id`, not `user_id`.
final class DeadlinesServiceImpl: DeadlinesManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func fetchDeadlines(familyUnitId: String) async throws -> [Deadline] {
    logger.debug("Fetching deadlines for family unit: \(familyUnitId)")

    let deadlines: [Deadline] = try await supabaseManager.client
      .from("user_deadlines")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .order("deadline_date", ascending: true)
      .execute()
      .value

    logger.info("Fetched \(deadlines.count) deadlines")
    return deadlines
  }

  func createDeadline(_ request: DeadlineCreateRequest) async throws -> Deadline {
    logger.debug("Creating deadline for user: \(request.userId)")

    let payload = DeadlineInsertPayload(
      userId: request.userId,
      familyUnitId: request.familyUnitId,
      label: request.label,
      deadlineDate: request.deadlineDate,
      category: request.category.rawValue,
      schoolId: request.schoolId
    )

    let deadline: Deadline = try await supabaseManager.client
      .from("user_deadlines")
      .insert(payload)
      .select()
      .single()
      .execute()
      .value

    logger.info("Created deadline: \(deadline.id)")
    return deadline
  }

  func deleteDeadline(id: String, familyUnitId: String) async throws {
    logger.debug("Deleting deadline: \(id)")

    try await supabaseManager.client
      .from("user_deadlines")
      .delete()
      .eq("id", value: id)
      .eq("family_unit_id", value: familyUnitId)
      .execute()

    logger.info("Deleted deadline: \(id)")
  }
}
