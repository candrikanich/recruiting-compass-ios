import Foundation
@testable import TheRecruitingCompass

final class MockActivityRealtimeService: ActivityRealtimeManaging, @unchecked Sendable {
  var shouldThrowOnSubscribe = false
  var errorToThrow: Error = NSError(domain: "MockActivityRealtime", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])

  var subscribeCallCount = 0
  var unsubscribeCallCount = 0
  var lastSubscribedFamilyUnitId: String?
  var subscribedFamilyUnitIds: [String] = []
  var events: [String] = []
  var lastOnInsert: (@MainActor @Sendable (ActivityEvent) -> Void)?
  var lastOnChange: (@MainActor @Sendable () -> Void)?
  var lastOnSchoolsChange: (@MainActor @Sendable () -> Void)?

  func subscribe(
    familyUnitId: String,
    onInsert: @escaping @MainActor @Sendable (ActivityEvent) -> Void,
    onChange: @escaping @MainActor @Sendable () -> Void,
    onSchoolsChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    subscribeCallCount += 1
    subscribedFamilyUnitIds.append(familyUnitId)
    events.append("subscribe:\(familyUnitId)")
    lastSubscribedFamilyUnitId = familyUnitId
    lastOnInsert = onInsert
    lastOnChange = onChange
    lastOnSchoolsChange = onSchoolsChange
    if shouldThrowOnSubscribe { throw errorToThrow }
  }

  func unsubscribe() async {
    unsubscribeCallCount += 1
    events.append("unsubscribe")
  }

  /// Test helper: simulate the realtime channel delivering a new event.
  @MainActor
  func simulateInsert(_ event: ActivityEvent) {
    lastOnInsert?(event)
  }

  /// Test helper: simulate an UPDATE/DELETE change that triggers full reload.
  @MainActor
  func simulateChange() {
    lastOnChange?()
  }

  @MainActor
  func simulateSchoolsChange() {
    lastOnSchoolsChange?()
  }
}
