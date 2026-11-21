import Foundation
import Supabase

/// Reads for the parent's first-run before the athlete joins.
protocol PendingAthleteManaging: Sendable {
  func fetchPendingAthlete(familyUnitId: String) async throws -> PendingAthlete?
  /// The grade's catalog tasks (not an athlete's statuses): there is no athlete to have any.
  func fetchTaskCatalog(gradeLevel: Int) async throws -> [TaskRow]
}

struct PendingAthleteServiceImpl: PendingAthleteManaging {
  let supabaseManager: SupabaseManager
  let apiClient: FamilyAPIClient

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
    self.apiClient = .live(supabaseManager)
  }

  func fetchPendingAthlete(familyUnitId: String) async throws -> PendingAthlete? {
    try await apiClient.fetchPendingAthlete(familyId: familyUnitId)
  }

  func fetchTaskCatalog(gradeLevel: Int) async throws -> [TaskRow] {
    try await supabaseManager.client
      .from("task")
      .select()
      .eq("grade_level", value: gradeLevel)
      .order("id", ascending: true)
      .execute()
      .value
  }
}
