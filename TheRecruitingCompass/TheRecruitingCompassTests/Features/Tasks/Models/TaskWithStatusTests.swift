import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class TaskWithStatusTests: XCTestCase {

  // MARK: - isLocked

  func testIsLocked_WhenHasIncompletePrerequisites_IsTrue() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      hasIncompletePrerequisites: true
    )
    XCTAssertTrue(task.isLocked)
  }

  func testIsLocked_WhenNoIncompletePrerequisites_IsFalse() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      hasIncompletePrerequisites: false
    )
    XCTAssertFalse(task.isLocked)
  }

  // MARK: - deadlineUrgency

  func testDeadlineUrgency_NilDate_IsNone() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      deadlineDate: nil,
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.deadlineUrgency, .none)
  }

  func testDeadlineUrgency_FutureDate_IsFutureOrUpcoming() {
    let ref = Calendar.current.startOfDay(for: Date())
    let in15 = Calendar.current.date(byAdding: .day, value: 15, to: ref)!
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      deadlineDate: in15,
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.deadlineUrgency, .future)
  }

  // MARK: - statusColor

  func testStatusColor_NoAthleteTask_IsSecondary() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      athleteTask: nil,
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.statusColor, .secondary)
  }

  func testStatusColor_Completed_IsGreen() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      athleteTask: AthleteTaskStatus(taskId: "1", userId: "u", status: .completed, completedAt: Date()),
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.statusColor, .successGreen)
  }

  func testStatusColor_InProgress_IsAmber() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      athleteTask: AthleteTaskStatus(taskId: "1", userId: "u", status: .inProgress, completedAt: nil),
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.statusColor, Color(hex: "F59E0B"))
  }

  // MARK: - effectiveStatus

  func testEffectiveStatus_NoAthleteTask_IsNotStarted() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      athleteTask: nil,
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.effectiveStatus, .notStarted)
  }

  func testEffectiveStatus_WithAthleteTask_ReturnsTaskStatus() {
    let task = TaskWithStatus(
      id: "1", title: "T", gradeLevel: 10, category: "c", required: true,
      athleteTask: AthleteTaskStatus(taskId: "1", userId: "u", status: .completed, completedAt: nil),
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.effectiveStatus, .completed)
  }

  // MARK: - Decoding

  func testDecode_MinimalJSON() throws {
    let json = """
    {
      "id": "task-1",
      "title": "Complete profile",
      "grade_level": 10,
      "category": "profile",
      "required": true,
      "has_incomplete_prerequisites": false
    }
    """
    let data = json.data(using: .utf8)!
    let task = try JSONDecoder().decode(TaskWithStatus.self, from: data)
    XCTAssertEqual(task.id, "task-1")
    XCTAssertEqual(task.title, "Complete profile")
    XCTAssertEqual(task.gradeLevel, 10)
    XCTAssertEqual(task.category, "profile")
    XCTAssertTrue(task.required)
    XCTAssertFalse(task.hasIncompletePrerequisites)
    XCTAssertNil(task.deadlineDate)
    XCTAssertNil(task.athleteTask)
    XCTAssertTrue(task.prerequisiteTasks.isEmpty)
  }

  func testDecode_WithOptionalFields() throws {
    let json = """
    {
      "id": "t2",
      "title": "Apply",
      "description": "Submit applications",
      "grade_level": 12,
      "category": "applications",
      "division": "I",
      "required": true,
      "deadline_date": "2026-03-01",
      "why_it_matters": "Important",
      "failure_risk": "Low",
      "dependency_task_ids": ["t1"],
      "has_incomplete_prerequisites": true
    }
    """
    let data = json.data(using: .utf8)!
    let task = try JSONDecoder().decode(TaskWithStatus.self, from: data)
    XCTAssertEqual(task.description, "Submit applications")
    XCTAssertEqual(task.division, "I")
    XCTAssertEqual(task.dependencyTaskIds, ["t1"])
    XCTAssertTrue(task.hasIncompletePrerequisites)
    XCTAssertNotNil(task.deadlineDate)
  }
}
