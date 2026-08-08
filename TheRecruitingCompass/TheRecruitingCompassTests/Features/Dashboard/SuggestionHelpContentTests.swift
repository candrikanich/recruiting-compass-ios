import XCTest
@testable import TheRecruitingCompass

final class SuggestionHelpContentTests: XCTestCase {
  func test_knownRuleType_returnsSpecificContent() {
    let c = SuggestionHelpContent.content(for: "school-list-building")
    XCTAssertEqual(c.title, "Build Your Target School List")
    XCTAssertFalse(c.howToComplete.isEmpty)
    XCTAssertFalse(c.coachesExpect.isEmpty)
  }

  func test_unknownRuleType_returnsGenericFallback() {
    let c = SuggestionHelpContent.content(for: "video-link-health")
    XCTAssertEqual(c.title, "Learn More")
    XCTAssertEqual(c.howToComplete, ["Focus on the suggested action above."])
  }

  func test_allSevenKnownKeysHaveEntries() {
    let keys = [
      "school-list-building", "showcase-attendance", "ncaa-registration",
      "formal-outreach", "official-visit", "missing-video", "interaction-gap"
    ]
    for key in keys {
      XCTAssertNotEqual(SuggestionHelpContent.content(for: key).title, "Learn More", "Missing entry for \(key)")
    }
  }
}
