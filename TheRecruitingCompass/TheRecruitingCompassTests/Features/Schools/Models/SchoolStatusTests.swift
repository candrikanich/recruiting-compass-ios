import XCTest
@testable import TheRecruitingCompass

final class SchoolStatusTests: XCTestCase {

  func testPipelineIsCanonicalFunnelOrder() {
    XCTAssertEqual(
      SchoolStatus.pipeline,
      [.researching, .contacted, .visiting, .offerReceived, .committed]
    )
  }

  func testSelectableIsPipelinePlusOffRamp() {
    XCTAssertEqual(
      SchoolStatus.selectable,
      [.researching, .contacted, .visiting, .offerReceived, .committed, .notPursuing]
    )
    // Deprecated/decode-only values must never be user-selectable.
    for deprecated in [SchoolStatus.interested, .campInvite, .recruited,
                       .officialVisitInvited, .officialVisitScheduled, .unknown] {
      XCTAssertFalse(SchoolStatus.selectable.contains(deprecated))
    }
  }

  func testRankIsMonotonicAcrossPipeline() {
    let ranks = SchoolStatus.pipeline.map(\.rank)
    XCTAssertEqual(ranks, ranks.sorted())
    XCTAssertEqual(Set(ranks).count, ranks.count, "Pipeline ranks must be strictly increasing")
  }

  func testOffRampRanksAfterEveryPipelineStage() {
    for stage in SchoolStatus.pipeline {
      XCTAssertGreaterThan(SchoolStatus.notPursuing.rank, stage.rank)
    }
  }

  func testDeprecatedValuesMapToCanonicalRank() {
    XCTAssertEqual(SchoolStatus.interested.rank, SchoolStatus.researching.rank)
    XCTAssertEqual(SchoolStatus.campInvite.rank, SchoolStatus.visiting.rank)
    XCTAssertEqual(SchoolStatus.recruited.rank, SchoolStatus.visiting.rank)
    XCTAssertEqual(SchoolStatus.officialVisitInvited.rank, SchoolStatus.visiting.rank)
    XCTAssertEqual(SchoolStatus.officialVisitScheduled.rank, SchoolStatus.visiting.rank)
  }

  func testUnknownRawValueDecodesToUnknown() throws {
    let decoded = try JSONDecoder().decode(SchoolStatus.self, from: Data("\"nonsense\"".utf8))
    XCTAssertEqual(decoded, .unknown)
  }

  func testCanonicalRawValuesRoundTrip() {
    XCTAssertEqual(SchoolStatus(rawValue: "offer_received"), .offerReceived)
    XCTAssertEqual(SchoolStatus(rawValue: "not_pursuing"), .notPursuing)
    XCTAssertEqual(SchoolStatus.visiting.rawValue, "visiting")
  }
}
