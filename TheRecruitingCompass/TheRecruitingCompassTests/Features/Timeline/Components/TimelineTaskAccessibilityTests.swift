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
    description: String? = nil,
    why: String? = nil,
    risk: String? = nil
  ) -> TaskWithStatus {
    TaskWithStatus(
      id: "t1", title: title, description: description, gradeLevel: 10, category: "eligibility",
      required: required, deadlineDate: deadline, whyItMatters: why, failureRisk: risk,
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
    let label = TimelineTaskAccessibility(task: task, phaseProgress: 100, isRecovery: true, isExpanded: false).label
    for fact in ["Register with the NCAA Eligibility Center", "Locked", "Recovery", "Due This Week", "Required"] {
      XCTAssertTrue(label.contains(fact), "label missing '\(fact)': \(label)")
    }
    XCTAssertTrue(label.contains(task.effectiveStatus.displayName))
  }

  func test_taskLabel_omitsAbsentFacts() {
    let label = TimelineTaskAccessibility(task: makeTask(required: false), phaseProgress: 100, isRecovery: false, isExpanded: false).label
    for absent in ["Locked", "Recovery", "Required", "Due"] {
      XCTAssertFalse(label.contains(absent), "unexpected '\(absent)': \(label)")
    }
  }

  func test_taskLabel_expandedIncludesDescription() {
    let task = makeTask(description: "Create your account and pay the fee.")
    let a11y = TimelineTaskAccessibility(task: task, phaseProgress: 100, isRecovery: false, isExpanded: true)
    XCTAssertTrue(a11y.label.contains("Create your account and pay the fee."))
    let collapsed = TimelineTaskAccessibility(task: task, phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertFalse(collapsed.label.contains("Create your account"))
  }

  // MARK: - Checkbox + actions

  func test_actions_openTaskWithDetails_offerCompleteAndDetails() {
    let task = makeTask(description: "Details")
    let a11y = TimelineTaskAccessibility(task: task, phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertEqual(a11y.actions, [.markComplete, .showDetails])
  }

  func test_actions_expandedTask_offersHideDetails() {
    let task = makeTask(description: "Details")
    let a11y = TimelineTaskAccessibility(task: task, phaseProgress: 100, isRecovery: false, isExpanded: true)
    XCTAssertEqual(a11y.actions, [.markComplete, .hideDetails])
  }

  func test_actions_completedTask_hasNoMarkComplete() {
    let a11y = TimelineTaskAccessibility(task: makeTask(status: .completed), phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertFalse(a11y.actions.contains(.markComplete))
  }

  func test_actions_lockedTask_explainsLockInsteadOfCompleting() {
    let a11y = TimelineTaskAccessibility(task: makeTask(locked: true), phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertEqual(a11y.actions, [.explainLock])
  }

  // MARK: - Phase-progress gating (web parity: failure risk only at >= 75%)

  func test_failureRisk_hiddenBelow75_notSpokenAndNotExpandable() {
    let task = makeTask(risk: "You could miss the window.")
    let a11y = TimelineTaskAccessibility(task: task, phaseProgress: 74, isRecovery: false, isExpanded: true)
    XCTAssertFalse(a11y.label.contains("miss the window"))
    XCTAssertFalse(a11y.isExpandable)
    XCTAssertEqual(a11y.actions, [.markComplete])
  }

  func test_failureRisk_shownAt75_spokenWhenExpanded() {
    let task = makeTask(risk: "You could miss the window.")
    let a11y = TimelineTaskAccessibility(task: task, phaseProgress: 75, isRecovery: false, isExpanded: true)
    XCTAssertTrue(a11y.label.contains("miss the window"))
    XCTAssertTrue(a11y.isExpandable)
    XCTAssertEqual(a11y.actions, [.markComplete, .hideDetails])
  }

  func test_whyItMatters_hiddenWhenCompleted() {
    let task = makeTask(status: .completed, why: "Colleges check this.")
    let a11y = TimelineTaskAccessibility(task: task, phaseProgress: 100, isRecovery: false, isExpanded: true)
    XCTAssertFalse(a11y.label.contains("Colleges check this."))
    XCTAssertEqual(a11y.actions, [])
  }

  // MARK: - Hint derives from actions

  func test_hint_completedTaskWithoutDetails_hasNoActionHint() {
    let a11y = TimelineTaskAccessibility(
      task: makeTask(status: .completed), phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertTrue(a11y.actions.isEmpty)
    XCTAssertEqual(a11y.hint, "")
  }

  func test_hint_listsExactlyTheOfferedActions() {
    let withDetails = TimelineTaskAccessibility(
      task: makeTask(description: "d"), phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertEqual(withDetails.hint, "Actions available: Mark complete, Show details")
    let noDetails = TimelineTaskAccessibility(
      task: makeTask(), phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertEqual(noDetails.hint, "Actions available: Mark complete")
  }

  func test_hint_tellsUserHowToComplete() {
    let a11y = TimelineTaskAccessibility(task: makeTask(), phaseProgress: 100, isRecovery: false, isExpanded: false)
    XCTAssertTrue(a11y.hint.contains("Mark complete"))
  }
}
