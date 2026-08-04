import Foundation
@testable import TheRecruitingCompass

final class MockActivityRealtimeService: ActivityRealtimeManaging, @unchecked Sendable {
  var shouldThrowOnSubscribe = false
  var errorToThrow: Error = NSError(domain: "MockActivityRealtime", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])

  var subscribeCallCount = 0
  var unsubscribeCallCount = 0
  var lastSubscribedUserId: String?
  var lastOnInsert: (@MainActor @Sendable (ActivityEvent) -> Void)?

  func subscribe(
    userId: String,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void
  ) async throws {
    subscribeCallCount += 1
    lastSubscribedUserId = userId
    lastOnInsert = onInsert
    if shouldThrowOnSubscribe { throw errorToThrow }
  }

  func unsubscribe() async {
    unsubscribeCallCount += 1
  }

  /// Test helper: simulate the realtime channel delivering a new event.
  @MainActor
  func simulateInsert(_ event: ActivityEvent) {
    lastOnInsert?(event)
  }
}
