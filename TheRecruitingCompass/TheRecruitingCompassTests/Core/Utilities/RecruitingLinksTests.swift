import XCTest
@testable import TheRecruitingCompass

/// Parity tests for the slug-based Prep Baseball Report link builder. URLs MUST
/// stay byte-identical with web `utils/recruitingLinks.ts`.
final class RecruitingLinksTests: XCTestCase {
  func testBuildURL_CodeAndName_MatchesWeb() {
    XCTAssertEqual(
      RecruitingLinks.buildPrepBaseballURL(state: "OH", name: "Owen Andrikanich"),
      "https://www.prepbaseballreport.com/profiles/OH/owen-andrikanich"
    )
  }

  func testBuildURL_FullStateName_NormalizesToCode() {
    XCTAssertEqual(
      RecruitingLinks.buildPrepBaseballURL(state: "Ohio", name: "Owen Andrikanich"),
      "https://www.prepbaseballreport.com/profiles/OH/owen-andrikanich"
    )
  }

  func testSlugify_ApostropheDroppedEntirely() {
    XCTAssertEqual(RecruitingLinks.slugifyPlayerName("O'Brien"), "obrien")
  }

  func testSlugify_PeriodsAndQuotesDropped_OtherRunsToSingleDash() {
    XCTAssertEqual(RecruitingLinks.slugifyPlayerName("A.J. \"Big\"  Smith"), "aj-big-smith")
  }

  func testSlugify_TrimsLeadingTrailingDashes() {
    XCTAssertEqual(RecruitingLinks.slugifyPlayerName("  --Owen--  "), "owen")
  }

  func testSlugify_EmptyOrNil_ReturnsEmpty() {
    XCTAssertEqual(RecruitingLinks.slugifyPlayerName(nil), "")
    XCTAssertEqual(RecruitingLinks.slugifyPlayerName(""), "")
  }

  func testNormalizeStateCode_CodePassThroughAndTrim() {
    XCTAssertEqual(RecruitingLinks.normalizeStateCode("  oh "), "OH")
    XCTAssertEqual(RecruitingLinks.normalizeStateCode("ca"), "CA")
  }

  func testNormalizeStateCode_FullNameLookup() {
    XCTAssertEqual(RecruitingLinks.normalizeStateCode("District of Columbia"), "DC")
    XCTAssertEqual(RecruitingLinks.normalizeStateCode("new york"), "NY")
  }

  func testNormalizeStateCode_InvalidReturnsNil() {
    XCTAssertNil(RecruitingLinks.normalizeStateCode("ZZ"))
    XCTAssertNil(RecruitingLinks.normalizeStateCode("Narnia"))
    XCTAssertNil(RecruitingLinks.normalizeStateCode(""))
    XCTAssertNil(RecruitingLinks.normalizeStateCode(nil))
  }

  func testBuildURL_InvalidState_ReturnsNil() {
    XCTAssertNil(RecruitingLinks.buildPrepBaseballURL(state: "ZZ", name: "Owen Andrikanich"))
  }

  func testBuildURL_EmptySlug_ReturnsNil() {
    XCTAssertNil(RecruitingLinks.buildPrepBaseballURL(state: "OH", name: "!!!"))
    XCTAssertNil(RecruitingLinks.buildPrepBaseballURL(state: "OH", name: nil))
  }

  func testStateTable_HasFiftyStatesPlusDC() {
    XCTAssertEqual(RecruitingLinks.stateNameToCode.count, 51)
    XCTAssertEqual(RecruitingLinks.stateCodes.count, 51)
  }

  func testProfileURL_PrepBaseballLinkKind_BuildsFromStateAndName() {
    guard let def = RecruitingServices.service(forKey: "prep_baseball_id") else {
      return XCTFail("PBR service def missing")
    }
    XCTAssertEqual(def.linkKind, .prepBaseball)
    XCTAssertEqual(
      RecruitingServices.profileURL(for: def, value: "ignored", state: "OH", name: "Owen Andrikanich"),
      "https://www.prepbaseballreport.com/profiles/OH/owen-andrikanich"
    )
  }
}
