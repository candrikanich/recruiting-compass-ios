import XCTest
@testable import TheRecruitingCompass

final class TemplateVariableTests: XCTestCase {

  nonisolated deinit {}

  func test_filmLinkVariablesAreOffered() {
    let keys = TemplateVariable.all.map(\.key)
    XCTAssertTrue(keys.contains("film_links"))
    XCTAssertTrue(keys.contains("primary_film_link"))
  }

  func test_substitutionReplacesFilmLinks() {
    let filled = CommunicationTemplate.substituteVariables(
      in: "Watch: {{primary_film_link}}",
      values: ["primary_film_link": "https://hudl.com/x"]
    )
    XCTAssertEqual(filled, "Watch: https://hudl.com/x")
  }
}
