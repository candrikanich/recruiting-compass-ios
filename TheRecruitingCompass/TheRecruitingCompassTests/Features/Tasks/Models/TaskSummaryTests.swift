import XCTest
@testable import TheRecruitingCompass

final class TaskSummaryTests: XCTestCase {

  func testIdentifiable_Id() {
    let summary = TaskSummary(id: "s1", title: "Summary Title")
    XCTAssertEqual(summary.id, "s1")
  }

  func testDecode_FromJSON() throws {
    let json = """
    {"id": "sum-1", "title": "Prerequisite task"}
    """
    let data = json.data(using: .utf8)!
    let summary = try JSONDecoder().decode(TaskSummary.self, from: data)
    XCTAssertEqual(summary.id, "sum-1")
    XCTAssertEqual(summary.title, "Prerequisite task")
  }
}
