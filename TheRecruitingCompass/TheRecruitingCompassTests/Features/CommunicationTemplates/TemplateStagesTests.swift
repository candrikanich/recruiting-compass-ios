import XCTest
@testable import TheRecruitingCompass

/// Mirrors web's `templateStages.spec.ts` — byte-identical stage labels/order,
/// same grouping behavior (#114, web parity with #519 / PR #721).
final class TemplateStagesTests: XCTestCase {

  func testGroupTemplatesByStage_GroupsUnderStageOrder_NotInputOrder() {
    let templates = [
      makeTemplate(name: "Asking for time on an offer", stage: "decision"),
      makeTemplate(name: "First contact", stage: "intro"),
      makeTemplate(name: "Quick update", stage: "update"),
    ]

    let groups = groupTemplatesByStage(templates)

    XCTAssertEqual(groups.map(\.stage), ["intro", "update", "decision"])
  }

  func testGroupTemplatesByStage_SortsWithinGroupAlphabeticallyByName() {
    let templates = [
      makeTemplate(name: "Reconnecting after a long gap", stage: "intro"),
      makeTemplate(name: "First contact", stage: "intro"),
    ]

    let groups = groupTemplatesByStage(templates)

    XCTAssertEqual(groups[0].templates.map(\.name), [
      "First contact",
      "Reconnecting after a long gap",
    ])
  }

  func testGroupTemplatesByStage_BucketsNilOrUnrecognizedStage_IntoTrailingOtherGroup() {
    let templates = [
      makeTemplate(name: "First contact", stage: "intro"),
      makeTemplate(name: "Custom template", stage: nil),
      makeTemplate(name: "Legacy template", stage: "not_a_real_stage"),
    ]

    let groups = groupTemplatesByStage(templates)

    XCTAssertNil(groups.last?.stage)
    XCTAssertEqual(groups.last?.label, "Other")
    XCTAssertEqual(groups.last?.templates.map(\.name), [
      "Custom template",
      "Legacy template",
    ])
  }

  func testGroupTemplatesByStage_OmitsEmptyGroups() {
    let templates = [makeTemplate(name: "First contact", stage: "intro")]

    let groups = groupTemplatesByStage(templates)

    XCTAssertEqual(groups.count, 1)
  }

  func testGroupTemplatesByStage_EmptyInput_ReturnsEmptyArray() {
    XCTAssertEqual(groupTemplatesByStage([]), [])
  }

  func testStageLabels_HasLabelForEveryDBCheckConstraintStage() {
    let dbStages = [
      "intro", "update", "event", "post_event", "thanks", "nudge",
      "reply", "visit", "status", "decision", "social",
    ]
    for stage in dbStages {
      XCTAssertNotNil(TemplateStage.labels[stage], "missing label for stage: \(stage)")
      XCTAssertTrue(TemplateStage.order.contains(stage), "missing from order: \(stage)")
    }
  }

  // MARK: - Helpers

  private func makeTemplate(name: String, stage: String?) -> CommunicationTemplate {
    CommunicationTemplate(
      id: name,
      userId: "user-1",
      name: name,
      type: .email,
      body: "",
      variables: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      stage: stage
    )
  }
}
