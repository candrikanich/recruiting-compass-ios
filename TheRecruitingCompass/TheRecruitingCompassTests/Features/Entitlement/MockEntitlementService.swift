import Foundation
@testable import TheRecruitingCompass

final class MockEntitlementService: EntitlementManaging, @unchecked Sendable {
  var subscription: FamilySubscription?
  var error: Error?
  var countdownVisible = true
  var countdownError: Error?
  private(set) var requestedFamilyIds: [String] = []

  /// Per-family rows for a payer in several families; a family without an entry falls back to `subscription`.
  var subscriptionsByFamilyId: [String: FamilySubscription] = [:]

  /// Awaited inside `fetchSubscription` so tests can hold a fetch in flight.
  var fetchGate: (@Sendable () async -> Void)?

  /// Awaited inside `fetchSubscription` with the family id so a test can hold one family's fetch in flight.
  var fetchGateByFamily: (@Sendable (String) async -> Void)?

  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? {
    requestedFamilyIds.append(familyUnitId)
    await fetchGate?()
    await fetchGateByFamily?(familyUnitId)
    if let error { throw error }
    return subscriptionsByFamilyId[familyUnitId] ?? subscription
  }

  func fetchTrialCountdownVisible() async throws -> Bool {
    if let countdownError { throw countdownError }
    return countdownVisible
  }
}
