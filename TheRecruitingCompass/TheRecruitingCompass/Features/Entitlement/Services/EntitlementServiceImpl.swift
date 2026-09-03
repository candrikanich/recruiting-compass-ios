import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "EntitlementService")

final class EntitlementServiceImpl: EntitlementManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? {
    logger.debug("Fetching subscription for family: \(familyUnitId)")

    let rows: [FamilySubscription] = try await supabaseManager.client
      .from("family_subscriptions")
      .select()
      .eq("family_unit_id", value: familyUnitId)
      .limit(1)
      .execute()
      .value

    return rows.first
  }
}
