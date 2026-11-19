import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DashboardService")

extension DashboardServiceImpl {
  func fetchFirstRunSignals(familyUnitId: String) async throws -> FirstRunSignals {
    async let coaches = exactCount(table: "coaches", column: "family_unit_id", value: familyUnitId)
    async let conversations = exactCount(table: "interactions", column: "family_unit_id", value: familyUnitId)
    async let favorites = fetchFavoriteSchoolNames(familyUnitId: familyUnitId)
    return try await FirstRunSignals(
      coachCount: coaches,
      conversationCount: conversations,
      favoriteSchoolName: favorites.first
    )
  }

  private struct SchoolNameRow: Decodable, Sendable {
    let name: String
  }

  private func fetchFavoriteSchoolNames(familyUnitId: String) async throws -> [String] {
    let rows: [SchoolNameRow] = try await logger.fetch("favorite school") {
      try await supabaseManager.client
        .from("schools")
        .select("name")
        .eq("family_unit_id", value: familyUnitId)
        .eq("is_favorite", value: true)
        .order("name", ascending: true)
        .limit(1)
        .execute()
        .value
    }
    return rows.map(\.name)
  }
}
