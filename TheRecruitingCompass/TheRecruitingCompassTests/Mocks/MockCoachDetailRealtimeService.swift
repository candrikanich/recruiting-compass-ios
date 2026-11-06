import Foundation
@testable import TheRecruitingCompass

/// Stands in for the Supabase Realtime subscription so view tests never open a live connection.
final class MockCoachDetailRealtimeService: CoachDetailRealtimeManaging, @unchecked Sendable {
  private let lock = NSLock()
  private var coachIds: [String] = []
  private var unsubscribes = 0

  var subscribedCoachIds: [String] { lock.withLock { coachIds } }
  var unsubscribeCount: Int { lock.withLock { unsubscribes } }

  func subscribe(
    coachId: String,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) async throws {
    lock.withLock { coachIds.append(coachId) }
  }

  func unsubscribe() async {
    lock.withLock { unsubscribes += 1 }
  }
}
