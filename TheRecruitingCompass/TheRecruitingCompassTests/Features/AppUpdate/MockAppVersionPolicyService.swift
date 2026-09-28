import Foundation
@testable import TheRecruitingCompass

final class MockAppVersionPolicyService: AppVersionPolicyFetching, @unchecked Sendable {
  var policy = AppVersionPolicy(minimumVersion: nil, recommendedVersion: nil)
  var error: Error?
  private(set) var fetchCount = 0

  /// Awaited inside `fetchPolicy` (after capturing the policy) so tests can hold a fetch in flight.
  var fetchGate: (@Sendable () async -> Void)?

  func fetchPolicy() async throws -> AppVersionPolicy {
    fetchCount += 1
    let captured = policy
    let gate = fetchGate
    fetchGate = nil
    await gate?()
    if let error { throw error }
    return captured
  }
}
