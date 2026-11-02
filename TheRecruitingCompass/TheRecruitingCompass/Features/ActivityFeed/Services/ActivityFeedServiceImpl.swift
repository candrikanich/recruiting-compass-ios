import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ActivityFeedService"
)

/// Sendable: Stateless service with no mutable properties
final class ActivityFeedServiceImpl: ActivityFeedManaging, Sendable {
  /// Per-source cap; matches web so both platforms merge the same window of entries.
  static let perSourceLimit = 200

  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchInteractions(familyUnitId: String) async throws -> [Interaction] {
    try await logger.fetch("interactions") {
      try await supabaseManager.client
        .from("interactions")
        .select("id, school_id, type, content, subject, occurred_at, created_at, direction, logged_by, family_unit_id, updated_at, sentiment, coach_id, attachments")
        .eq("family_unit_id", value: familyUnitId)
        .order("created_at", ascending: false)
        .limit(Self.perSourceLimit)
        .execute()
        .value
    }
  }

  func fetchStatusChanges(familyUnitId: String) async throws -> [SchoolStatusHistory] {
    try await logger.fetch("status changes") {
      try await supabaseManager.client
        .from("school_status_history")
        .select("id, school_id, new_status, previous_status, notes, changed_at, changed_by, created_at, schools!inner(family_unit_id)")
        .eq("schools.family_unit_id", value: familyUnitId)
        .order("changed_at", ascending: false)
        .limit(Self.perSourceLimit)
        .execute()
        .value
    }
  }

  func fetchDocuments(familyUnitId: String) async throws -> [DocumentRecord] {
    try await logger.fetch("documents") {
      try await supabaseManager.client
        .from("documents")
        .select("id, title, type, created_at, user_id")
        .eq("family_unit_id", value: familyUnitId)
        .order("created_at", ascending: false)
        .limit(Self.perSourceLimit)
        .execute()
        .value
    }
  }

  func fetchSchoolNames(schoolIds: [String]) async throws -> [String: String] {
    guard !schoolIds.isEmpty else { return [:] }

    logger.debug("Hydrating \(schoolIds.count) school names")

    struct SchoolNameRecord: Codable {
      let id: String
      let name: String
    }

    do {
      let records: [SchoolNameRecord] = try await supabaseManager.client
        .from("schools")
        .select("id, name")
        .in("id", values: schoolIds)
        .execute()
        .value
      let nameMap = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.name) })
      logger.info("Hydrated \(nameMap.count) school names")
      return nameMap
    } catch {
      logger.error("fetchSchoolNames failed: \(error.localizedDescription)")
      throw error
    }
  }
}
