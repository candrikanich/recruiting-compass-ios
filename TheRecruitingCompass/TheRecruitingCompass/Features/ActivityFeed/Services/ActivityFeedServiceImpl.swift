import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ActivityFeedService"
)

/// Sendable: Stateless service with no mutable properties
final class ActivityFeedServiceImpl: ActivityFeedManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchInteractions(userId: String) async throws -> [Interaction] {
    logger.info("Fetching interactions for activity feed, user: \(userId)")

    let interactions: [Interaction] = try await supabaseManager.client
      .from("interactions")
      .select("id, school_id, type, content, subject, occurred_at, created_at, direction, logged_by, family_unit_id, updated_at, sentiment, coach_id, attachments")
      .eq("logged_by", value: userId)
      .order("created_at", ascending: false)
      .limit(50)
      .execute()
      .value

    logger.info("Fetched \(interactions.count) interactions for activity feed")
    return interactions
  }

  func fetchStatusChanges(userId: String) async throws -> [SchoolStatusHistory] {
    logger.info("Fetching status changes for activity feed, user: \(userId)")

    let changes: [SchoolStatusHistory] = try await supabaseManager.client
      .from("school_status_history")
      .select("id, school_id, new_status, previous_status, notes, changed_at, changed_by, created_at")
      .eq("changed_by", value: userId)
      .order("changed_at", ascending: false)
      .limit(50)
      .execute()
      .value

    logger.info("Fetched \(changes.count) status changes for activity feed")
    return changes
  }

  func fetchDocuments(userId: String) async throws -> [DocumentRecord] {
    logger.info("Fetching documents for activity feed, user: \(userId)")

    let documents: [DocumentRecord] = try await supabaseManager.client
      .from("documents")
      .select("id, title, type, created_at")
      .eq("user_id", value: userId)
      .order("created_at", ascending: false)
      .limit(50)
      .execute()
      .value

    logger.info("Fetched \(documents.count) documents for activity feed")
    return documents
  }

  func fetchSchoolNames(schoolIds: [String]) async throws -> [String: String] {
    guard !schoolIds.isEmpty else { return [:] }

    logger.info("Hydrating \(schoolIds.count) school names")

    struct SchoolNameRecord: Codable {
      let id: String
      let name: String
    }

    let records: [SchoolNameRecord] = try await supabaseManager.client
      .from("schools")
      .select("id, name")
      .in("id", values: schoolIds)
      .execute()
      .value

    let nameMap = Dictionary(
      uniqueKeysWithValues: records.map { ($0.id, $0.name) }
    )

    logger.info("Hydrated \(nameMap.count) school names")
    return nameMap
  }
}
