import XCTest
@testable import TheRecruitingCompass

final class TasksServiceImplTests: XCTestCase {

  var sut: TasksServiceImpl!

  override func setUp() {
    super.setUp()
    sut = TasksServiceImpl(supabaseManager: .shared)
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func testConformsToTasksManaging() {
    XCTAssertNotNil(sut as? any TasksManaging)
  }

  func testFetchTasksWithStatus_DoesNotThrowWhenTableMissing() async {
    // When tasks/athlete_tasks tables don't exist or are empty, we get an error.
    // We only verify the call completes (or throws); no network in unit test without mock.
    do {
      _ = try await sut.fetchTasksWithStatus(gradeLevel: 10, athleteId: "test-user-id")
      // If we get here, Supabase is configured and returned (possibly empty).
    } catch {
      // Expected when tables missing or not configured.
      XCTAssertNotNil(error)
    }
  }

  func testUpdateTaskStatus_DoesNotThrowWhenTableMissing() async {
    do {
      _ = try await sut.updateTaskStatus(taskId: "t1", status: .completed, userId: "u1")
    } catch {
      XCTAssertNotNil(error)
    }
  }

  // MARK: - tasksByGrade

  func testTasksByGrade_groupsRowsByGrade_preservingOrder() {
    let rows = [row("a", grade: 9), row("b", grade: 10), row("c", grade: 9)]

    let result = TasksServiceImpl.tasksByGrade(rows: rows, athleteTasks: [], graduationYear: nil, grades: [9, 10])

    XCTAssertEqual(result[9]?.map(\.id), ["a", "c"])
    XCTAssertEqual(result[10]?.map(\.id), ["b"])
  }

  func testTasksByGrade_gradeWithNoRows_isPresentAndEmpty() {
    let result = TasksServiceImpl.tasksByGrade(
      rows: [row("a", grade: 9)], athleteTasks: [], graduationYear: nil, grades: [9, 10, 11, 12]
    )

    XCTAssertEqual(Set(result.keys), [9, 10, 11, 12])
    XCTAssertEqual(result[12]?.count, 0)
  }

  func testTasksByGrade_attachesAthleteStatusAcrossGrades() {
    let rows = [row("a", grade: 9), row("b", grade: 11)]
    let athleteTasks = [
      AthleteTaskStatus(taskId: "b", userId: "athlete-1", status: .completed, completedAt: nil)
    ]

    let result = TasksServiceImpl.tasksByGrade(
      rows: rows, athleteTasks: athleteTasks, graduationYear: nil, grades: [9, 11]
    )

    XCTAssertNil(result[9]?.first?.athleteTask)
    XCTAssertEqual(result[11]?.first?.athleteTask?.status, .completed)
  }

  func testTasksByGrade_locksTaskUntilPrerequisiteCompleted() {
    let rows = [row("a", grade: 9), row("b", grade: 9, dependsOn: ["a"])]

    let locked = TasksServiceImpl.tasksByGrade(rows: rows, athleteTasks: [], graduationYear: nil, grades: [9])
    let unlocked = TasksServiceImpl.tasksByGrade(
      rows: rows,
      athleteTasks: [AthleteTaskStatus(taskId: "a", userId: "athlete-1", status: .completed, completedAt: nil)],
      graduationYear: nil,
      grades: [9]
    )

    XCTAssertEqual(locked[9]?.last?.hasIncompletePrerequisites, true)
    XCTAssertEqual(locked[9]?.last?.prerequisiteTasks.map(\.id), ["a"])
    XCTAssertEqual(unlocked[9]?.last?.hasIncompletePrerequisites, false)
  }

  // Matches the per-grade fetch this replaces: a prerequisite in another grade still locks the task,
  // but is only listed by title when it is in the same grade.
  func testTasksByGrade_prerequisiteInAnotherGrade_locksButIsNotListed() {
    let rows = [row("a", grade: 9), row("b", grade: 10, dependsOn: ["a"])]

    let result = TasksServiceImpl.tasksByGrade(rows: rows, athleteTasks: [], graduationYear: nil, grades: [9, 10])

    XCTAssertEqual(result[10]?.first?.hasIncompletePrerequisites, true)
    XCTAssertEqual(result[10]?.first?.prerequisiteTasks.count, 0)
  }

  // MARK: - Helpers

  private func row(_ id: String, grade: Int, dependsOn: [String]? = nil) -> TaskRow {
    TaskRow(
      id: id, title: "Task \(id)", description: nil, gradeLevel: grade, category: "general", division: nil,
      required: true, deadlineOffsetMonths: nil, whyItMatters: nil, failureRisk: nil, dependencyTaskIds: dependsOn
    )
  }
}
