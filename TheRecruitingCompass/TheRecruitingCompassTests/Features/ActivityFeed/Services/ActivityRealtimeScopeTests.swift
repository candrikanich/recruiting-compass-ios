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
    var registry = ChannelRegistry<String>()
    let generation = registry.generation

    _ = registry.drain()

    XCTAssertFalse(registry.adopt("late-channel", generation: generation))
    XCTAssertTrue(registry.drain().isEmpty)
  }

  func testChannelRegistry_adoptsForCurrentGenerationAndDrainsThem() {
    var registry = ChannelRegistry<String>()
    let generation = registry.generation

    XCTAssertTrue(registry.adopt("a", generation: generation))
    XCTAssertTrue(registry.adopt("b", generation: generation))

    XCTAssertEqual(registry.drain(), ["a", "b"])
    XCTAssertTrue(registry.drain().isEmpty)
  }
}
