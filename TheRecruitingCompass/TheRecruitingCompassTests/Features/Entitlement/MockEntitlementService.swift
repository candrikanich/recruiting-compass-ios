import Foundation
@testable import TheRecruitingCompass

final class MockEntitlementService: EntitlementManaging, @unchecked Sendable {
  var subscription: FamilySubscription?
  var error: Error?
  private(set) var requestedFamilyIds: [String] = []

  func fetchSubscription(familyUnitId: String) async throws -> FamilySubscription? {
    requestedFamilyIds.append(familyUnitId)
    if let error { throw error }
    return subscription
  }
}
