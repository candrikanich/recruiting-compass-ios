import XCTest
@testable import TheRecruitingCompass

final class TemplateVariableExtractorTests: XCTestCase {
  private func def(_ key: String, _ type: VariableSourceType, label: String = "") -> TemplateVariableDef {
    TemplateVariableDef(key: key, label: label.isEmpty ? key : label, category: "", sourceType: type)
  }

  func test_returnsReferencedVarsInFirstSeenOrderWithTags() {
    let registry = [
      def("coachSalutation", .computed, label: "Coach Salutation"),
      def("programNote", .authored, label: "Program Note"),
      def("schoolShortName", .computed)
    ]
    let vars = TemplateVariableExtractor.referenced(
      subject: "Hi {{coachSalutation}}",
      body: "{{programNote}} — go {{schoolShortName}}. {{programNote}} again.",
      registry: registry,
      resolvedValues: ["coachSalutation": "Coach Smith", "schoolShortName": "Duke"])
    XCTAssertEqual(vars.map(\.key), ["coachSalutation", "programNote", "schoolShortName"])
    XCTAssertEqual(vars[0].isResolved, true)
    XCTAssertEqual(vars[0].resolvedValue, "Coach Smith")
    XCTAssertEqual(vars[1].isAuthored, true)
    XCTAssertEqual(vars[1].isResolved, false)
    XCTAssertEqual(vars[1].label, "Program Note")
  }

  func test_unknownTokenReturnedWithKeyLabel() {
    let vars = TemplateVariableExtractor.referenced(
      subject: nil, body: "{{mysteryVar}}", registry: [], resolvedValues: [:])
    XCTAssertEqual(vars.map(\.key), ["mysteryVar"])
    XCTAssertEqual(vars[0].sourceType, .unknown)
    XCTAssertFalse(vars[0].isAuthored)
  }

  func test_noTokensEmpty() {
    XCTAssertTrue(TemplateVariableExtractor.referenced(
      subject: "plain", body: "no tokens", registry: [], resolvedValues: [:]).isEmpty)
  }
}
