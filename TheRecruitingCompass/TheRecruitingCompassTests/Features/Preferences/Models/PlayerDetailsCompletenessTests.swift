import XCTest
@testable import TheRecruitingCompass

/// Canonical profile-completeness formula — see
/// `planning/2026-08-09-profile-completeness-canonical-spec.md`. Weights must match
/// the web implementation (`utils/profileCompletenessCalculation.ts`).
final class PlayerDetailsCompletenessTests: XCTestCase {
  nonisolated deinit {}

  private func score(_ d: PlayerDetails, video: Bool = false, location: Bool = false) -> Double {
    d.completenessScore(hasHighlightVideo: video, hasHomeLocation: location)
  }

  func testEmptyProfileIsZero() {
    XCTAssertEqual(score(PlayerDetails()), 0.0, accuracy: 0.0001)
  }

  func testEachFieldContributesItsWeight() {
    XCTAssertEqual(score(PlayerDetails(graduationYear: 2026)), 0.10, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(primarySport: "Soccer")), 0.10, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(primaryPosition: "Forward")), 0.10, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(gpa: 3.5)), 0.15, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(satScore: 1200)), 0.10, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(actScore: 28)), 0.10, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(heightInches: 70)), 0.05, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(weightLbs: 160)), 0.05, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(phone: "555-1234")), 0.10, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(), video: true), 0.15, accuracy: 0.0001)
    XCTAssertEqual(score(PlayerDetails(), location: true), 0.10, accuracy: 0.0001)
  }

  func testSatAndActCountAsOneField() {
    let both = PlayerDetails(satScore: 1200, actScore: 28)
    XCTAssertEqual(score(both), 0.10, accuracy: 0.0001)
  }

  func testWhitespaceStringsAreNotCounted() {
    let d = PlayerDetails(primarySport: "  ", primaryPosition: "\n", phone: " ")
    XCTAssertEqual(score(d), 0.0, accuracy: 0.0001)
  }

  func testNonCanonicalFieldsDoNotContribute() {
    let d = PlayerDetails(
      highSchool: "HS", primarySport: nil, bats: "R", throws_: "R",
      twitterHandle: "@x", schoolName: "S", schoolCity: "C", schoolState: "TX"
    )
    XCTAssertEqual(score(d), 0.0, accuracy: 0.0001)
  }

  func testAllFieldsSumToOne() {
    let d = PlayerDetails(
      graduationYear: 2026, primarySport: "Soccer", primaryPosition: "Forward",
      heightInches: 70, weightLbs: 160, gpa: 3.5, satScore: 1200, phone: "555-1234"
    )
    XCTAssertEqual(score(d, video: true, location: true), 1.0, accuracy: 0.0001)
  }

  func testIsCompleteWithoutVideo() {
    // Video (15%) is excluded from the badge — all other fields filled → complete.
    let d = PlayerDetails(
      graduationYear: 2026, primarySport: "Soccer", primaryPosition: "Forward",
      heightInches: 70, weightLbs: 160, gpa: 3.5, satScore: 1200, phone: "555-1234"
    )
    XCTAssertTrue(d.isComplete(hasHomeLocation: true))
  }

  func testIsCompleteFalseWhenNonVideoFieldMissing() {
    // Missing phone (10%) drops score below 0.85 → incomplete.
    let d = PlayerDetails(
      graduationYear: 2026, primarySport: "Soccer", primaryPosition: "Forward",
      heightInches: 70, weightLbs: 160, gpa: 3.5, satScore: 1200
      // phone: nil
    )
    XCTAssertFalse(d.isComplete(hasHomeLocation: true))
  }
}

final class HomeLocationPresenceTests: XCTestCase {
  nonisolated deinit {}

  func testEmptyIsNotSet() {
    XCTAssertFalse(HomeLocation().isSet)
  }

  func testZipMakesItSet() {
    XCTAssertTrue(HomeLocation(zip: "60601").isSet)
  }

  func testBlankZipIsNotSet() {
    XCTAssertFalse(HomeLocation(zip: "  ").isSet)
  }

  func testCoordinatePairMakesItSet() {
    XCTAssertTrue(HomeLocation(latitude: 41.8, longitude: -87.6).isSet)
  }

  func testLoneLatitudeIsNotSet() {
    XCTAssertFalse(HomeLocation(latitude: 41.8).isSet)
  }
}
