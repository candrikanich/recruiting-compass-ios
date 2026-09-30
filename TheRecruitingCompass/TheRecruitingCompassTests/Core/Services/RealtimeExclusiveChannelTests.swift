import XCTest
import Supabase
@testable import TheRecruitingCompass

final class RealtimeExclusiveChannelTests: XCTestCase {
  private let client = RealtimeClientV2(
    url: URL(string: "wss://example.invalid/realtime/v1")!,
    options: RealtimeClientOptions(headers: ["apikey": "test-anon-key"])
  )

  /// The SDK behavior the helper exists for: a plain `channel(_:)` with a live topic is shared.
  func testPlainChannelWithSameTopicIsShared() {
    XCTAssertTrue(client.channel("dashboard-schools-f1") === client.channel("dashboard-schools-f1"))
  }

  func testExclusiveChannelsWithSameNameAreDistinct() {
    let first = client.exclusiveChannel("dashboard-schools-f1")
    let second = client.exclusiveChannel("dashboard-schools-f1")

    XCTAssertFalse(first === second)
    XCTAssertNotEqual(first.topic, second.topic)
  }

  func testExclusiveChannelKeepsNameAsTopicPrefix() {
    let channel = client.exclusiveChannel("coach-detail-c1")

    XCTAssertTrue(channel.topic.hasPrefix("realtime:coach-detail-c1-"), channel.topic)
  }
}
