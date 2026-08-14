import XCTest
@testable import TheRecruitingCompass

final class TemplateResolverTests: XCTestCase {
  func test_fillsKnownTokens() {
    let out = TemplateResolver.render("Hi {{coachName}} at {{schoolName}}",
                                      values: ["coachName": "Smith", "schoolName": "Wooster"])
    XCTAssertEqual(out, "Hi Smith at Wooster")
  }

  func test_leavesUnknownTokensIntact() {
    let out = TemplateResolver.render("Hi {{coachName}}, {{programNote}}",
                                      values: ["coachName": "Smith"])
    XCTAssertEqual(out, "Hi Smith, {{programNote}}")
  }

  func test_findUnresolvedReturnsRemainingKeysDeduped() {
    let text = "{{programNote}} and {{updateHook}} and {{programNote}}"
    XCTAssertEqual(TemplateResolver.findUnresolved(text), ["programNote", "updateHook"])
  }

  func test_findUnresolvedEmptyWhenAllResolved() {
    XCTAssertEqual(TemplateResolver.findUnresolved("no tokens here"), [])
  }
}
