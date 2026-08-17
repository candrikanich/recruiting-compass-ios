import XCTest
@testable import TheRecruitingCompass

final class TimelineTaskSortTests: XCTestCase {

  // MARK: - Fixture builder

  private func makeTask(
    id: String,
    title: String = "Task",
    category: String = "academic",
    required: Bool = true,
    deadlineDate: Date? = nil,
    completed: Bool = false,
    locked: Bool = false
  ) -> TaskWithStatus {
    let athleteTask = completed
      ? AthleteTaskStatus(taskId: id, userId: "athlete", status: .completed, completedAt: nil)
      : nil
    return TaskWithStatus(
      id: id,
      title: title,
      gradeLevel: 10,
      category: category,
      required: required,
      deadlineDate: deadlineDate,
      athleteTask: athleteTask,
      hasIncompletePrerequisites: locked
    )
  }

  private func date(_ iso: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "UTC")
    return f.date(from: iso)!
  }

  private func order(_ tasks: [TaskWithStatus]) -> [String] {
    TimelineTaskSort.sorted(tasks).map(\.id)
  }

  // MARK: - Individual keys

  func testCompletedSinksBelowIncomplete() {
    let done = makeTask(id: "done", completed: true)
    let open = makeTask(id: "open", completed: false)
    XCTAssertEqual(order([done, open]), ["open", "done"])
  }

  func testLockedSinksBelowActionable() {
    let locked = makeTask(id: "locked", locked: true)
    let actionable = makeTask(id: "actionable", locked: false)
    XCTAssertEqual(order([locked, actionable]), ["actionable", "locked"])
  }

  func testRequiredBeforeOptional() {
    let optional = makeTask(id: "optional", required: false)
    let required = makeTask(id: "required", required: true)
    XCTAssertEqual(order([optional, required]), ["required", "optional"])
  }

  func testEarlierDeadlineFirst_NilLast() {
    let none = makeTask(id: "none", deadlineDate: nil)
    let later = makeTask(id: "later", deadlineDate: date("2027-06-01"))
    let overdue = makeTask(id: "overdue", deadlineDate: date("2020-01-01"))
    XCTAssertEqual(order([none, later, overdue]), ["overdue", "later", "none"])
  }

  func testCategoryRankOrder_UnknownLast() {
    let mindset = makeTask(id: "mindset", category: "mindset")
    let academic = makeTask(id: "academic", category: "academic")
    let exposure = makeTask(id: "exposure", category: "exposure")
    let recruiting = makeTask(id: "recruiting", category: "recruiting")
    let athletic = makeTask(id: "athletic", category: "athletic")
    let unknown = makeTask(id: "unknown", category: "mystery")
    XCTAssertEqual(
      order([mindset, unknown, academic, exposure, recruiting, athletic]),
      ["academic", "recruiting", "athletic", "exposure", "mindset", "unknown"]
    )
  }

  func testTitleTiebreakAlphabetical() {
    let bravo = makeTask(id: "bravo", title: "Bravo")
    let alpha = makeTask(id: "alpha", title: "alpha")
    XCTAssertEqual(order([bravo, alpha]), ["alpha", "bravo"])
  }

  // MARK: - Precedence + combined

  func testRequiredBeatsDeadline() {
    // An overdue optional task still sorts below an upcoming required task.
    let optionalOverdue = makeTask(id: "opt", required: false, deadlineDate: date("2020-01-01"))
    let requiredLater = makeTask(id: "req", required: true, deadlineDate: date("2030-01-01"))
    XCTAssertEqual(order([optionalOverdue, requiredLater]), ["req", "opt"])
  }

  func testLockedBeatsRequired() {
    // A locked required task sorts below an actionable optional task.
    let lockedRequired = makeTask(id: "locked", required: true, locked: true)
    let actionableOptional = makeTask(id: "open", required: false, locked: false)
    XCTAssertEqual(order([lockedRequired, actionableOptional]), ["open", "locked"])
  }

  func testFullOrdering() {
    let completed = makeTask(id: "completed", completed: true)
    let locked = makeTask(id: "locked", locked: true)
    let requiredSoon = makeTask(id: "requiredSoon", required: true, deadlineDate: date("2025-01-01"))
    let requiredLater = makeTask(id: "requiredLater", required: true, deadlineDate: date("2026-01-01"))
    let optionalNoDeadline = makeTask(id: "optional", required: false, deadlineDate: nil)

    let sorted = order([completed, optionalNoDeadline, locked, requiredLater, requiredSoon])
    XCTAssertEqual(sorted, ["requiredSoon", "requiredLater", "optional", "locked", "completed"])
  }

  func testFullyEqualKeysPreserveInputOrder() {
    let taskA = makeTask(id: "a", title: "Same", category: "academic")
    let taskB = makeTask(id: "b", title: "Same", category: "academic")
    // All comparison keys tie (title equal) → comparator returns false → input
    // order is preserved, no crash, deterministic per input.
    XCTAssertEqual(order([taskA, taskB]), ["a", "b"])
    XCTAssertEqual(order([taskB, taskA]), ["b", "a"])
  }
}
