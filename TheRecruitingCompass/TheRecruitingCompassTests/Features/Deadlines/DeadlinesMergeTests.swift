import XCTest
@testable import TheRecruitingCompass

final class DeadlinesMergeTests: XCTestCase {
  private func deadline(_ id: String, _ date: String, label: String = "User item") -> Deadline {
    Deadline(id: id, userId: "u1", familyUnitId: "f1", label: label, deadlineDate: date,
             category: .application, schoolId: nil, createdAt: nil, updatedAt: nil)
  }

  private func milestone(_ date: String, _ title: String) -> CalendarMilestone {
    CalendarMilestone(date: date, title: title, type: .deadline)
  }

  func test_unify_sortsAscendingByDate() {
    let result = DeadlinesMerge.unify(
      userDeadlines: [deadline("a", "2026-12-01")],
      milestones: [milestone("2026-09-01", "Early test date")]
    )
    XCTAssertEqual(result.map(\.date), ["2026-09-01", "2026-12-01"])
  }

  func test_unify_dedupesCoincidentSameSourceEntries() {
    let result = DeadlinesMerge.unify(
      userDeadlines: [],
      milestones: [milestone("2026-09-01", "SAT Test"), milestone("2026-09-01", "SAT Test")]
    )
    XCTAssertEqual(result.count, 1)
  }

  func test_unify_userAndSystemOnSameDateDifferentLabelBothSurface() {
    let result = DeadlinesMerge.unify(
      userDeadlines: [deadline("a", "2026-09-01", label: "My essay due")],
      milestones: [milestone("2026-09-01", "SAT Test")]
    )
    XCTAssertEqual(result.count, 2)
  }

  func test_unify_userItemCarriesUnderlyingDeadlineForDelete() {
    let d = deadline("a", "2026-09-01")
    let result = DeadlinesMerge.unify(userDeadlines: [d], milestones: [])
    XCTAssertEqual(result.first?.userDeadline, d)
    XCTAssertTrue(result.first?.isRemovable ?? false)
  }

  func test_unify_systemItemHasNoUnderlyingDeadline() {
    let result = DeadlinesMerge.unify(userDeadlines: [], milestones: [milestone("2026-09-01", "SAT")])
    XCTAssertNil(result.first?.userDeadline)
    XCTAssertFalse(result.first?.isRemovable ?? true)
  }

  func test_groupByMonth_groupsByYearMonthPrefix() {
    let items = DeadlinesMerge.unify(
      userDeadlines: [deadline("a", "2026-09-05"), deadline("b", "2026-09-20"), deadline("c", "2026-10-01")],
      milestones: []
    )
    let grouped = DeadlinesMerge.groupByMonth(items)
    XCTAssertEqual(grouped.map(\.month), ["2026-09", "2026-10"])
    XCTAssertEqual(grouped.first?.items.count, 2)
    XCTAssertEqual(grouped.last?.items.count, 1)
  }

  func test_splitUpcomingPast_partitionsOnTodayInclusiveOfToday() {
    let items = DeadlinesMerge.unify(
      userDeadlines: [deadline("past", "2026-01-01"), deadline("today", "2026-06-15"), deadline("future", "2026-12-01")],
      milestones: []
    )
    let (upcoming, past) = DeadlinesMerge.splitUpcomingPast(items, today: "2026-06-15")
    XCTAssertEqual(upcoming.map(\.id), items.filter { $0.date >= "2026-06-15" }.map(\.id))
    XCTAssertEqual(past.map(\.id), items.filter { $0.date < "2026-06-15" }.map(\.id))
    XCTAssertTrue(upcoming.contains { $0.date == "2026-06-15" })
  }
}
