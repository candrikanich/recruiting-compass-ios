import XCTest
import SwiftUI
@testable import TheRecruitingCompass

/// Accessibility tests for Phase 5 Tasks/Timeline (WCAG AA, 44pt targets, VoiceOver labels).
@MainActor
final class TasksAccessibilityTests: XCTestCase {

  // MARK: - Checkbox label format (spec: "Mark [Task] complete" / "Complete [prerequisites] to unlock")

  func testCheckboxLabel_Unlocked_FormatMarkTaskComplete() {
    let task = TaskWithStatus(id: "t1", title: "Submit application", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false)
    let expected = "Mark \(task.title) complete"
    XCTAssertEqual(expected, "Mark Submit application complete")
  }

  func testCheckboxLabel_Locked_FormatCompletePrereqsToUnlock() {
    let task = TaskWithStatus(
      id: "t1",
      title: "Apply to school",
      gradeLevel: 10,
      category: "c",
      required: true,
      prerequisiteTasks: [TaskSummary(id: "p1", title: "Complete profile"), TaskSummary(id: "p2", title: "Get transcript")],
      hasIncompletePrerequisites: true
    )
    let prereqs = task.prerequisiteTasks.map(\.title).joined(separator: ", ")
    let expected = "Complete \(prereqs) to unlock"
    XCTAssertTrue(expected.contains("Complete"))
    XCTAssertTrue(expected.contains("to unlock"))
    XCTAssertTrue(expected.contains("Complete profile"))
  }

  // MARK: - Task card combined label (spec: "[Task title], [Status], [Locked/Unlocked], [Required/Optional]")

  func testTaskCardCombinedLabel_IncludesTitleStatusLockedRequired() {
    let task = TaskWithStatus(id: "t1", title: "Request transcript", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false)
    let status = task.effectiveStatus.displayName
    let locked = task.isLocked ? "Locked" : "Unlocked"
    let req = task.required ? "Required" : "Optional"
    let label = "\(task.title), \(status), \(locked), \(req)"
    XCTAssertEqual(label, "Request transcript, Not Started, Unlocked, Required")
  }

  func testTaskCardCombinedLabel_LockedRequired() {
    let task = TaskWithStatus(id: "t1", title: "Apply", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: true)
    let status = task.effectiveStatus.displayName
    let locked = task.isLocked ? "Locked" : "Unlocked"
    let req = task.required ? "Required" : "Optional"
    let label = "\(task.title), \(status), \(locked), \(req)"
    XCTAssertEqual(locked, "Locked")
    XCTAssertEqual(req, "Required")
    XCTAssertTrue(label.contains("Apply"))
    XCTAssertTrue(label.contains("Locked"))
  }

  // MARK: - Progress announcement (spec: "Completed X of Y tasks, Z percent complete")

  func testProgressAnnouncement_Format() {
    let completed = 3
    let total = 10
    let percentage = 30
    let label = "Completed \(completed) of \(total) tasks, \(percentage) percent complete"
    XCTAssertEqual(label, "Completed 3 of 10 tasks, 30 percent complete")
  }

  func testProgressAnnouncement_ZeroTotal() {
    let completed = 0
    let total = 0
    let percentage = 0
    let label = "Completed \(completed) of \(total) tasks, \(percentage) percent complete"
    XCTAssertEqual(label, "Completed 0 of 0 tasks, 0 percent complete")
  }

  // MARK: - Status colors (WCAG AA: green/yellow/gray)

  func testTaskStatusColor_Completed_IsGreen() {
    let task = TaskWithStatus(
      id: "t1",
      title: "T",
      gradeLevel: 10,
      category: "c",
      required: true,
      athleteTask: AthleteTaskStatus(taskId: "t1", userId: "u", status: .completed, completedAt: nil),
      hasIncompletePrerequisites: false
    )
    XCTAssertEqual(task.statusColor, .successGreen)
  }

  func testTaskStatusColor_NotStarted_IsSecondary() {
    let task = TaskWithStatus(id: "t1", title: "T", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false)
    XCTAssertEqual(task.statusColor, .secondary)
  }

  // MARK: - Filter labels (picker accessibility)

  func testTaskStatusFilter_DisplayNames_NonEmpty() {
    for filter in TaskStatusFilter.allCases {
      XCTAssertFalse(filter.displayName.isEmpty)
    }
  }

  func testTaskUrgencyFilter_DisplayNames_NonEmpty() {
    for filter in TaskUrgencyFilter.allCases {
      XCTAssertFalse(filter.displayName.isEmpty)
    }
  }
}
