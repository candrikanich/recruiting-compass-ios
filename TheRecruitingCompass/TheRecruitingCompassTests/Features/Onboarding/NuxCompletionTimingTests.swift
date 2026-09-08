import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("NuxCompletionTiming — 24h auto-hide window")
struct NuxCompletionTimingTests {

  @Test func notExpiredRightAtZeroHours() {
    let now = Date()
    #expect(!NuxCompletionTiming.hasExpired(now, now: now))
  }

  @Test func notExpiredJustUnder24Hours() {
    let now = Date()
    let completedAt = now.addingTimeInterval(-(24 * 3600 - 1))
    #expect(!NuxCompletionTiming.hasExpired(completedAt, now: now))
  }

  @Test func expiredExactlyAt24Hours() {
    let now = Date()
    let completedAt = now.addingTimeInterval(-24 * 3600)
    #expect(NuxCompletionTiming.hasExpired(completedAt, now: now))
  }

  @Test func expiredAfter24Hours() {
    let now = Date()
    let completedAt = now.addingTimeInterval(-25 * 3600)
    #expect(NuxCompletionTiming.hasExpired(completedAt, now: now))
  }

  @Test func autoHideThresholdIs24Hours() {
    #expect(NuxCompletionTiming.autoHideThresholdHours == 24)
  }
}
