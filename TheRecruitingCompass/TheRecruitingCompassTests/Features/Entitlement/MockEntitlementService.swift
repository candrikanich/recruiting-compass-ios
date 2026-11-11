import Foundation
@testable import TheRecruitingCompass

final class MockEntitlementService: EntitlementManaging, @unchecked Sendable {
  var subscription: FamilySubscription?
  var error: Error?
  var countdownVisible = true
  var countdownError: Error?
  private(set) var requestedFamilyIds: [String] = []

  /// Awaited inside `fetchSubscription` so tests can hold a fetch in flight.
  var fetchGate: (@Sendable () async -> Void)?

  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? {
    requestedFamilyIds.append(familyUnitId)
    await fetchGate?()
    if let error { throw error }
    return subscription
  }

  func fetchTrialCountdownVisible() async throws -> Bool {
    if let countdownError { throw countdownError }
    return countdownVisible
  }
}
