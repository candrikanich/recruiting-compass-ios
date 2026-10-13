import XCTest
@testable import TheRecruitingCompass

final class TimelineTaskAccessibilityTests: XCTestCase {
  private func makeTask(
    title: String = "Register with the NCAA Eligibility Center",
    required: Bool = true,
    deadline: Date? = nil,
    status: TaskStatus? = nil,
    recovery: Bool = false,
    locked: Bool = false,
    description: String? = nil
  ) -> TaskWithStatus {
    TaskWithStatus(
      id: "t1", title: title, description: description, gradeLevel: 10, category: "eligibility",
      required: required, deadlineDate: deadline,
      athleteTask: status.map { AthleteTaskStatus(taskId: "t1", userId: "u", status: $0, completedAt: nil) },
      hasIncompletePrerequisites: locked
    )
  }

  // MARK: - Phase header

  func test_phaseHeader_collapsed_reportsValueAndHint() {
    let a11y = PhaseCardAccessibility(phaseLabel: "Junior Year", completed: 3, total: 8, isExpanded: false)
    XCTAssertEqual(a11y.label, "Junior Year, 3 of 8 tasks complete")
    XCTAssertEqual(a11y.value, "Collapsed")
    XCTAssertTrue(a11y.hint.contains("show tasks"))
  }

  func test_phaseHeader_expanded_reportsValueAndHint() {
    let a11y = PhaseCardAccessibility(phaseLabel: "Junior Year", completed: 3, total: 8, isExpanded: true)
    XCTAssertEqual(a11y.value, "Expanded")
    XCTAssertTrue(a11y.hint.contains("hide tasks"))
  }

  // MARK: - Task row label

  func test_taskLabel_speaksEveryVisibleFact() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)
    let task = makeTask(deadline: tomorrow, status: .inProgress, locked: true)
    let label = TimelineTaskAccessibility(task: task, isRecovery: true, isExpanded: false).label
    for fact in ["Register with the NCAA Eligibility Center", "Locked", "Recovery", "Due This Week", "Required"] {
      XCTAssertTrue(label.contains(fact), "label missing '\(fact)': \(label)")
    }
    XCTAssertTrue(label.contains(task.effectiveStatus.displayName))
  }

  func test_taskLabel_omitsAbsentFacts() {
    let label = TimelineTaskAccessibility(task: makeTask(required: false), isRecovery: false, isExpanded: false).label
    for absent in ["Locked", "Recovery", "Required", "Due"] {
      XCTAssertFalse(label.contains(absent), "unexpected '\(absent)': \(label)")
    }
  }

  func test_taskLabel_expandedIncludesDescription() {
    let task = makeTask(description: "Create your account and pay the fee.")
    let a11y = TimelineTaskAccessibility(task: task, isRecovery: false, isExpanded: true)
    XCTAssertTrue(a11y.label.contains("Create your account and pay the fee."))
    let collapsed = TimelineTaskAccessibility(task: task, isRecovery: false, isExpanded: false)
    XCTAssertFalse(collapsed.label.contains("Create your account"))
  }

  // MARK: - Checkbox + actions

  func test_checkboxLabel_namesTheTask() {
    let a11y = TimelineTaskAccessibility(task: makeTask(), isRecovery: false, isExpanded: false)
    XCTAssertEqual(a11y.checkboxLabel, "Mark Register with the NCAA Eligibility Center complete")
  }

  func test_actions_openTaskWithDetails_offerCompleteAndDetails() {
    let task = makeTask(description: "Details")
    let a11y = TimelineTaskAccessibility(task: task, isRecovery: false, isExpanded: false)
    XCTAssertEqual(a11y.actions, [.markComplete, .showDetails])
  }

  func test_actions_expandedTask_offersHideDetails() {
    let task = makeTask(description: "Details")
    let a11y = TimelineTaskAccessibility(task: task, isRecovery: false, isExpanded: true)
    XCTAssertEqual(a11y.actions, [.markComplete, .hideDetails])
  }

  func test_actions_completedTask_hasNoMarkComplete() {
    let a11y = TimelineTaskAccessibility(task: makeTask(status: .completed), isRecovery: false, isExpanded: false)
    XCTAssertFalse(a11y.actions.contains(.markComplete))
  }

  func test_actions_lockedTask_explainsLockInsteadOfCompleting() {
    let a11y = TimelineTaskAccessibility(task: makeTask(locked: true), isRecovery: false, isExpanded: false)
    XCTAssertEqual(a11y.actions, [.explainLock])
  }

  func test_hint_tellsUserHowToComplete() {
    let a11y = TimelineTaskAccessibility(task: makeTask(), isRecovery: false, isExpanded: false)
    XCTAssertTrue(a11y.hint.contains("Mark complete"))
  }
}
