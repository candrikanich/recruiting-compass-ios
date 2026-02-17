import XCTest
@testable import TheRecruitingCompass

final class AthleteTaskStatusTests: XCTestCase {

  func testDecode_FromJSON() throws {
    let json = """
    {
      "task_id": "task-1",
      "user_id": "user-1",
      "status": "completed",
      "completed_at": "2026-01-15T12:00:00Z"
    }
    """
    let data = json.data(using: .utf8)!
    let status = try JSONDecoder().decode(AthleteTaskStatus.self, from: data)
    XCTAssertEqual(status.taskId, "task-1")
    XCTAssertEqual(status.userId, "user-1")
    XCTAssertEqual(status.status, .completed)
    XCTAssertNotNil(status.completedAt)
  }

  func testDecode_NoCompletedAt() throws {
    let json = """
    {"task_id": "t1", "user_id": "u1", "status": "in_progress"}
    """
    let data = json.data(using: .utf8)!
    let status = try JSONDecoder().decode(AthleteTaskStatus.self, from: data)
    XCTAssertEqual(status.status, .inProgress)
    XCTAssertNil(status.completedAt)
  }

  func testInit_Values() {
    let status = AthleteTaskStatus(taskId: "t1", userId: "u1", status: .notStarted, completedAt: nil)
    XCTAssertEqual(status.taskId, "t1")
    XCTAssertEqual(status.userId, "u1")
    XCTAssertEqual(status.status, .notStarted)
    XCTAssertNil(status.completedAt)
  }
}
