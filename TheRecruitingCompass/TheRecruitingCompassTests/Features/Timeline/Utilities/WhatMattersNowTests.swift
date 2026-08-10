import XCTest
@testable import TheRecruitingCompass

final class WhatMattersNowTests: XCTestCase {
  nonisolated deinit {}

  private func task(
    id: String,
    gradeLevel: Int,
    category: String = "training",
    required: Bool = true,
    whyItMatters: String? = "Because it matters",
    status: TaskStatus? = nil,
    dependencyTaskIds: [String] = []
  ) -> TaskWithStatus {
    TaskWithStatus(
      id: id,
      title: "Task \(id)",
      gradeLevel: gradeLevel,
      category: category,
      required: required,
      whyItMatters: whyItMatters,
      dependencyTaskIds: dependencyTaskIds,
      athleteTask: status.map { AthleteTaskStatus(taskId: id, userId: "u", status: $0, completedAt: nil) },
      hasIncompletePrerequisites: false
    )
  }

  func testReturnsNilWhenNoTasks() {
    XCTAssertNil(WhatMattersNow.topPriority(phase: .junior, tasks: []))
  }

  func testOnlyConsidersCurrentPhaseGrade() {
    let tasks = [
      task(id: "9", gradeLevel: 9),   // freshman, wrong grade for junior
      task(id: "11", gradeLevel: 11)  // junior
    ]
    XCTAssertEqual(WhatMattersNow.topPriority(phase: .junior, tasks: tasks)?.id, "11")
  }

  func testSkipsCompletedTasks() {
    let tasks = [
      task(id: "done", gradeLevel: 11, status: .completed),
      task(id: "pending", gradeLevel: 11, status: .notStarted)
    ]
    XCTAssertEqual(WhatMattersNow.topPriority(phase: .junior, tasks: tasks)?.id, "pending")
  }

  func testSkipsOptionalAndMissingWhyItMatters() {
    let tasks = [
      task(id: "optional", gradeLevel: 11, required: false),
      task(id: "noWhy", gradeLevel: 11, whyItMatters: nil),
      task(id: "empty", gradeLevel: 11, whyItMatters: ""),
      task(id: "valid", gradeLevel: 11)
    ]
    XCTAssertEqual(WhatMattersNow.topPriority(phase: .junior, tasks: tasks)?.id, "valid")
  }

  func testRanksByCategoryPriority() {
    let tasks = [
      task(id: "low", gradeLevel: 11, category: "training"),          // 5
      task(id: "high", gradeLevel: 11, category: "academic-standing") // 10
    ]
    XCTAssertEqual(WhatMattersNow.topPriority(phase: .junior, tasks: tasks)?.id, "high")
  }

  func testDependencyBonusRaisesPriority() {
    let tasks = [
      task(id: "evaluation", gradeLevel: 11, category: "evaluation"),                       // 7
      task(id: "docWithDep", gradeLevel: 11, category: "documentation", dependencyTaskIds: ["x"]) // 6 + 2 = 8
    ]
    XCTAssertEqual(WhatMattersNow.topPriority(phase: .junior, tasks: tasks)?.id, "docWithDep")
  }

  func testTieResolvesToEarliestInputOrder() {
    let tasks = [
      task(id: "first", gradeLevel: 11, category: "communication"), // 8
      task(id: "second", gradeLevel: 11, category: "communication") // 8
    ]
    XCTAssertEqual(WhatMattersNow.topPriority(phase: .junior, tasks: tasks)?.id, "first")
  }
}
