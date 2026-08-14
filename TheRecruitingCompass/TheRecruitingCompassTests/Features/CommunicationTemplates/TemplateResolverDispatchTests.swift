import XCTest
@testable import TheRecruitingCompass

final class TemplateResolverDispatchTests: XCTestCase {
  private func ctx(
    tables: [String: [String: String]] = [:], prefs: [String: String] = [:],
    authored: [String: String] = [:], derived: [String: String] = [:]
  ) -> ResolverContext {
    ResolverContext(tables: tables, prefs: prefs, authored: authored, derived: derived,
                    metrics: [], events: [], now: Date(timeIntervalSince1970: 0))
  }

  func test_columnSourceResolvesFromKnownTable() {
    let c = ctx(tables: ["coaches": ["first_name": "Sam"]])
    XCTAssertEqual(TemplateResolver.resolveSourcePath("column:coaches.first_name", c), "Sam")
  }

  func test_columnSourceUnknownTableIsNil() {
    let c = ctx(tables: ["widgets": ["x": "y"]])
    XCTAssertNil(TemplateResolver.resolveSourcePath("column:widgets.x", c))
  }

  func test_prefSourceResolvesFromPrefs() {
    let c = ctx(prefs: ["ncaa_id": "1902"])
    XCTAssertEqual(TemplateResolver.resolveSourcePath("pref:player.ncaa_id", c), "1902")
  }

  func test_buildValuesOmitsEmptyAndDispatchesBySourceType() {
    let registry = [
      TemplateVariableDef(key: "coachFirstName", label: "", category: "program",
                          sourceType: .column, sourcePath: "column:coaches.first_name"),
      TemplateVariableDef(key: "playerPhone", label: "", category: "contacts",
                          sourceType: .column, sourcePath: "pref:player.phone"),
      TemplateVariableDef(key: "programNote", label: "", category: "authored",
                          sourceType: .authored),
      TemplateVariableDef(key: "sport", label: "", category: "player", sourceType: .computed),
      TemplateVariableDef(key: "missing", label: "", category: "contacts",
                          sourceType: .column, sourcePath: "pref:player.absent")
    ]
    let c = ctx(tables: ["coaches": ["first_name": "Sam"]],
                prefs: ["phone": "555-0100"],
                authored: ["programNote": "loved the camp"],
                derived: ["sport": "Baseball"])
    let values = TemplateResolver.buildValues(registry: registry, context: c)
    XCTAssertEqual(values["coachFirstName"], "Sam")
    XCTAssertEqual(values["playerPhone"], "555-0100")
    XCTAssertEqual(values["programNote"], "loved the camp")
    XCTAssertEqual(values["sport"], "Baseball")
    XCTAssertNil(values["missing"], "unresolved key omitted, not empty-string")
  }

  func test_endToEndRenderLeavesUnresolvedForGating() {
    let registry = [TemplateVariableDef(key: "coachSalutation", label: "", category: "program",
                                        sourceType: .computed)]
    let c = ctx(derived: ["coachSalutation": "Coach Smith"])
    let values = TemplateResolver.buildValues(registry: registry, context: c)
    let body = TemplateResolver.render("{{coachSalutation}}, {{programNote}}", values: values)
    XCTAssertEqual(body, "Coach Smith, {{programNote}}")
    XCTAssertEqual(TemplateResolver.findUnresolved(body), ["programNote"])
  }
}
