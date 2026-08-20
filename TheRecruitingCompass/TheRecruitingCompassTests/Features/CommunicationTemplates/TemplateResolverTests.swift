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

  // MARK: - Optional segments [[gate|text]]

  func test_optionalSegment_keptWhenGateResolved() {
    let out = TemplateResolver.applyOptionalSegments(
      "Film: {{videoLink}}[[videoLink| Happy to answer questions about my film.]]",
      values: ["videoLink": "http://x"]
    )
    XCTAssertEqual(out, "Film: {{videoLink}} Happy to answer questions about my film.")
  }

  func test_optionalSegment_droppedWhenGateMissing() {
    let out = TemplateResolver.applyOptionalSegments(
      "Numbers{{metrics}}[[videoLink| Happy to answer questions about my film.]]",
      values: [:]
    )
    XCTAssertEqual(out, "Numbers{{metrics}}")
  }

  func test_renderClean_dropsFilmProseWhenNoFilm() {
    let body = "My numbers are strong.\n[[videoLink|I'd welcome feedback on my film to fit at {{schoolName}}.]]\nThanks"
    let out = TemplateResolver.renderClean(body, values: ["schoolName": "Wooster"], requiredKeys: [])
    XCTAssertFalse(out.contains("film"))
    XCTAssertTrue(out.contains("My numbers are strong."))
    XCTAssertTrue(out.contains("Thanks"))
  }

  func test_renderClean_keepsFilmProseWhenFilmPresent() {
    let body = "[[videoLink|I'd welcome feedback on my film to fit at {{schoolName}}.]]"
    let out = TemplateResolver.renderClean(
      body, values: ["videoLink": "http://x", "schoolName": "Wooster"], requiredKeys: []
    )
    XCTAssertEqual(out, "I'd welcome feedback on my film to fit at Wooster.")
  }

  func test_renderClean_dropsMajorClauseWhenUnset() {
    let body = "- {{gpa}} GPA[[intendedMajor|, planning to study {{intendedMajor}}]]"
    let out = TemplateResolver.renderClean(body, values: ["gpa": "3.8"], requiredKeys: [])
    XCTAssertEqual(out, "- 3.8 GPA")
  }

  func test_renderClean_keepsMajorClauseWhenSet() {
    let body = "- {{gpa}} GPA[[intendedMajor|, planning to study {{intendedMajor}}]]"
    let out = TemplateResolver.renderClean(
      body, values: ["gpa": "3.8", "intendedMajor": "Biology"], requiredKeys: []
    )
    XCTAssertEqual(out, "- 3.8 GPA, planning to study Biology")
  }
}
