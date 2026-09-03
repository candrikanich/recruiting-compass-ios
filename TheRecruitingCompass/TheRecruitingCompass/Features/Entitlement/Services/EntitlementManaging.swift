import Foundation

protocol EntitlementManaging: Sendable {
  /// Returns nil when the family has no subscription row (should not happen after the trigger, but tolerate it).
  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription?
}
