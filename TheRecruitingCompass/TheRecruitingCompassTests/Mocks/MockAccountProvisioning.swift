import Foundation
@testable import TheRecruitingCompass

final class MockAccountProvisioning: AccountProvisioning, @unchecked Sendable {
  private(set) var flushCallCount = 0
  /// Fires synchronously when flush is called — tests use this to capture caller state
  /// (e.g. AuthManager.isAuthenticated) at the exact moment flush runs, to prove ordering.
  var onFlush: (@MainActor () -> Void)?

  func flushPendingOnboardingStep1() async {
    flushCallCount += 1
    await MainActor.run { self.onFlush?() }
  }
}
