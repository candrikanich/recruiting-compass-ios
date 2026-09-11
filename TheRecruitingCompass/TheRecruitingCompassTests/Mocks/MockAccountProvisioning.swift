import Foundation
@testable import TheRecruitingCompass

final class MockAccountProvisioning: AccountProvisioning, @unchecked Sendable {
  private(set) var flushCallCount = 0

  func flushPendingOnboardingStep1() async {
    flushCallCount += 1
  }
}
