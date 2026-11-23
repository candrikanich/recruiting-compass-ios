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

  /// Errors thrown by the Nth `fetchSubscription` call (0-based), overriding `error`.
  var errorsByCallIndex: [Int: Error] = [:]

  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? {
    let callIndex = requestedFamilyIds.count
    requestedFamilyIds.append(familyUnitId)
    await fetchGate?()
    await fetchGateByFamily?(familyUnitId)
    if let error = errorsByCallIndex[callIndex] { throw error }
    if let error { throw error }
    return subscriptionsByFamilyId[familyUnitId] ?? subscription
  }

  func fetchTrialCountdownVisible() async throws -> Bool {
    if let countdownError { throw countdownError }
    return countdownVisible
  }

  /// Hands the Nth gated fetch (0-based) its own gate, so a test controls each fetch independently.
  @MainActor
  func gateEachCall(_ gates: [AsyncGate]) {
    fetchGateByFamily = { _ in
      for gate in gates {
        if await gate.enteredCount == 0 {
          await gate.wait()
          return
        }
      }
    }
  }
}
