import XCTest
@testable import TheRecruitingCompass

final class ActivityRealtimeScopeTests: XCTestCase {
  func testFamilyFilter_scopesToFamilyUnitId() {
    XCTAssertEqual(ActivityRealtimeService.familyFilter("fam-A"), "family_unit_id=eq.fam-A")
  }

  func testStatusHistorySubscription_isTheUnfilteredHistoryTable() {
    XCTAssertEqual(ActivityRealtimeService.statusHistoryTable, "school_status_history")
    XCTAssertNil(ActivityRealtimeService.statusHistoryFilter, "the table has no family column to filter on")
  }

  func testChannelRegistry_refusesAChannelJoinedForAnEndedSubscription() {
    let registry = ChannelRegistry<String>()
    let generation = registry.generation

    _ = registry.drain()

    XCTAssertFalse(registry.adopt("late-channel", generation: generation))
    XCTAssertTrue(registry.drain().isEmpty)
  }

  func testChannelRegistry_adoptsForCurrentGenerationAndDrainsThem() {
    let registry = ChannelRegistry<String>()
    let generation = registry.generation

    XCTAssertTrue(registry.adopt("a", generation: generation))
    XCTAssertTrue(registry.adopt("b", generation: generation))

    XCTAssertEqual(registry.drain(), ["a", "b"])
    XCTAssertTrue(registry.drain().isEmpty)
  }

  private struct JoinFailure: Error {}

  func testJoin_endedWhileJoining_removesTheChannelAndReportsSupersession() async throws {
    let registry = ChannelRegistry<String>()
    let generation = registry.generation
    var removed: [String] = []

    let adopted = try await registry.join(
      "ch", generation: generation,
      subscribe: { _ = registry.drain() },
      remove: { removed.append($0) }
    )

    XCTAssertFalse(adopted)
    XCTAssertEqual(removed, ["ch"])
    XCTAssertTrue(registry.drain().isEmpty, "a superseded channel must not be tracked")
  }

  func testJoin_failure_removesTheChannelAndRethrows() async {
    let registry = ChannelRegistry<String>()
    var removed: [String] = []

    do {
      _ = try await registry.join(
        "ch", generation: registry.generation, subscribe: { throw JoinFailure() }, remove: { removed.append($0) })
      XCTFail("expected the join error")
    } catch {
      XCTAssertTrue(error is JoinFailure)
    }
    XCTAssertEqual(removed, ["ch"])
  }

  func testJoinBestEffort_failureLeavesTheOtherChannelsAdopted() async throws {
    let registry = ChannelRegistry<String>()
    let generation = registry.generation
    var failures = 0

    _ = try await registry.join("interactions", generation: generation, subscribe: {}, remove: { _ in })
    let historyAdopted = await registry.joinBestEffort(
      "history", generation: generation, subscribe: { throw JoinFailure() }, remove: { _ in },
      onFailure: { _ in failures += 1 })
    _ = try await registry.join("documents", generation: generation, subscribe: {}, remove: { _ in })

    XCTAssertFalse(historyAdopted)
    XCTAssertEqual(failures, 1)
    XCTAssertEqual(registry.drain(), ["interactions", "documents"])
  }
}
