import XCTest
@testable import TheRecruitingCompass

/// Shared vectors with web `renderClean` — keep the two byte-identical.
final class TemplateRenderCleanTests: XCTestCase {
  private let required: Set<String> = ["programNote"]

  func test_dropsLabelOnlyLineForEmptyOptional() {
    let body = "Film: {{videoLink}}\nThanks"
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: [:], requiredKeys: required),
      "Thanks")
  }

  func test_keepsLineWhenOptionalResolves() {
    let body = "Film: {{videoLink}}\nThanks"
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: ["videoLink": "https://film/1"], requiredKeys: required),
      "Film: https://film/1\nThanks")
  }

  func test_requiredUnresolvedTokenSurvives() {
    let body = "Hi,\n{{programNote}}\nThanks"
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: [:], requiredKeys: required),
      "Hi,\n{{programNote}}\nThanks")
  }

  func test_dropsEmptyBulletLine() {
    let body = "Numbers:\n- {{metrics}}\nEnd"
    // metrics optional + empty → the bullet line goes; the header stays.
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: [:], requiredKeys: required),
      "Numbers:\nEnd")
  }

  func test_tidiesFooterWithSomeResolved() {
    let body = "{{gradYear}} | {{position}} | {{highSchool}}"
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: ["gradYear": "2028"], requiredKeys: required),
      "2028")
  }

  func test_dropsFooterWhenAllOptionalEmpty() {
    let body = "Signed,\n{{gradYear}} | {{position}} | {{highSchool}}"
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: [:], requiredKeys: required),
      "Signed,")
  }

  func test_collapsesBlankLinesLeftByDrop() {
    let body = "A\n\nFilm: {{videoLink}}\n\nB"
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: [:], requiredKeys: required),
      "A\n\nB")
  }

  func test_mixedOptionalAndRequiredOnSameLineKeepsRequired() {
    let body = "{{position}} — {{programNote}}"
    // position optional (stripped), programNote required (stays); dangling sep trimmed.
    XCTAssertEqual(
      TemplateResolver.renderClean(body, values: [:], requiredKeys: required),
      "{{programNote}}")
  }
}
