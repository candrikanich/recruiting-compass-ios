import Foundation
import Observation
import OSLog

/// App-wide family entitlement state. Source of truth is `family_subscriptions` in Supabase;
/// this mirrors it for UI. Phase 0: only the Settings Plan row reads it.
@Observable
@MainActor
final class EntitlementStore {
  nonisolated deinit {}

  private(set) var subscription: FamilySubscription?
  private(set) var isLoading = false
  private(set) var errorMessage: String?

  private let service: any EntitlementManaging
  private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "EntitlementStore")

  var canWrite: Bool { subscription?.canWrite() ?? false }
  var planLabel: String { subscription?.planLabel() ?? PlanLabel.unavailable }

  init(service: any EntitlementManaging = EntitlementServiceImpl(supabaseManager: .shared)) {
    self.service = service
  }

  func load(familyUnitId: String?) async {
    guard let familyUnitId else {
      subscription = nil
      errorMessage = nil
      return
    }
    isLoading = true
    defer { isLoading = false }
    do {
      subscription = try await service.fetchSubscription(familyUnitId: familyUnitId)
      errorMessage = nil
    } catch {
      subscription = nil
      errorMessage = error.localizedDescription
      logger.error("Failed to load entitlement: \(error.localizedDescription)")
    }
  }
}
