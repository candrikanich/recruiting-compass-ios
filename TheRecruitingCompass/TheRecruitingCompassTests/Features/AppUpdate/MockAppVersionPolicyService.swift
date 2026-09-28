import Foundation
@testable import TheRecruitingCompass

final class MockAppVersionPolicyService: AppVersionPolicyFetching, @unchecked Sendable {
  var policy = AppVersionPolicy(minimumVersion: nil, recommendedVersion: nil)
  var error: Error?
  private(set) var fetchCount = 0

  func fetchPolicy() async throws -> AppVersionPolicy {
    fetchCount += 1
    if let error { throw error }
    return policy
  }
}
