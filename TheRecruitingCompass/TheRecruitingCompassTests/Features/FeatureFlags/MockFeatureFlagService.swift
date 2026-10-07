import Foundation
@testable import TheRecruitingCompass

final class MockFeatureFlagService: FeatureFlagFetching, @unchecked Sendable {
  var disabledKeys: [String] = []
  var error: Error?
  private(set) var fetchCount = 0

  func fetchDisabledFeatureKeys() async throws -> [String] {
    fetchCount += 1
    if let error { throw error }
    return disabledKeys
  }
}
