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

  func test_filter_noFiltersReturnsAllItems() {
    let items = DeadlinesMerge.unify(
      userDeadlines: [deadline("a", "2026-09-01", label: "Essay")],
      milestones: [milestone("2026-09-02", "SAT Test")]
    )
    let result = DeadlinesMerge.filter(items, category: nil, search: "")
    XCTAssertEqual(result.count, 2)
  }

  func test_filter_byCategoryMatchesRawCategoryKey() {
    let items = DeadlinesMerge.unify(
      userDeadlines: [deadline("a", "2026-09-01", label: "Essay")],
      milestones: [milestone("2026-09-02", "SAT Test")]
    )
    let result = DeadlinesMerge.filter(items, category: "application", search: "")
    XCTAssertEqual(result.map(\.id), items.filter { $0.userDeadline != nil }.map(\.id))
  }

  func test_filter_bySearchIsCaseInsensitiveOnLabel() {
    let items = DeadlinesMerge.unify(
      userDeadlines: [deadline("a", "2026-09-01", label: "FAFSA Deadline")],
      milestones: [milestone("2026-09-02", "SAT Test")]
    )
    let result = DeadlinesMerge.filter(items, category: nil, search: "fafsa")
    XCTAssertEqual(result.map(\.id), ["user-a"])
  }

  func test_filter_combinesCategoryAndSearch() {
    let items = DeadlinesMerge.unify(
      userDeadlines: [deadline("a", "2026-09-01", label: "FAFSA Deadline")],
      milestones: [milestone("2026-09-02", "FAFSA reminder")]
    )
    let result = DeadlinesMerge.filter(items, category: "application", search: "fafsa")
    XCTAssertEqual(result.map(\.id), ["user-a"])
  }

  func test_buildCalendarGrid_startsOnSundayAndHas42Cells() {
    // 2026-09-01 is a Tuesday; Sunday-start grid must spill back to 2026-08-30.
    let grid = DeadlinesMerge.buildCalendarGrid(year: 2026, month: 9)
    XCTAssertEqual(grid.count, 42)
    XCTAssertEqual(grid.first?.date, "2026-08-30")
    XCTAssertFalse(grid.first?.isCurrentMonth ?? true)
  }

  func test_buildCalendarGrid_includesEveryDayOfCurrentMonth() {
    let grid = DeadlinesMerge.buildCalendarGrid(year: 2026, month: 9)
    let currentMonthDays = grid.filter(\.isCurrentMonth)
    XCTAssertEqual(currentMonthDays.count, 30) // September has 30 days
    XCTAssertEqual(currentMonthDays.first?.date, "2026-09-01")
    XCTAssertEqual(currentMonthDays.last?.date, "2026-09-30")
  }

  func test_buildCalendarGrid_datesAreContiguousNoUTCOffByOne() {
    // Regression guard: a UTC/toISOString-based implementation would produce
    // a duplicate or skipped day at local-timezone boundaries.
    let grid = DeadlinesMerge.buildCalendarGrid(year: 2026, month: 9)
    let formatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyy-MM-dd"
      f.calendar = Calendar(identifier: .gregorian)
      f.timeZone = TimeZone.current
      f.locale = Locale(identifier: "en_US_POSIX")
      return f
    }()
    var previous: Date?
    for day in grid {
      guard let date = formatter.date(from: day.date) else { return XCTFail("Unparseable date \(day.date)") }
      if let previous {
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: previous)!
        XCTAssertEqual(Calendar.current.startOfDay(for: date), Calendar.current.startOfDay(for: expected))
      }
      previous = date
    }
  }

  func test_buildCalendarGrid_handlesDecemberToJanuaryYearBoundary() {
    let grid = DeadlinesMerge.buildCalendarGrid(year: 2026, month: 12)
    let currentMonthDays = grid.filter(\.isCurrentMonth)
    XCTAssertEqual(currentMonthDays.count, 31)
    XCTAssertTrue(grid.last!.date > "2026-12-31") // spills into January
  }

  func test_buildCalendarGrid_handlesLeapFebruary() {
    let grid = DeadlinesMerge.buildCalendarGrid(year: 2028, month: 2)
    XCTAssertEqual(grid.filter(\.isCurrentMonth).count, 29)
  }

  func test_groupByDate_keysByISODate() {
    let items = DeadlinesMerge.unify(
      userDeadlines: [
        deadline("a", "2026-09-05", label: "Essay due"),
        deadline("b", "2026-09-05", label: "Visit"),
        deadline("c", "2026-09-06", label: "FAFSA due")
      ],
      milestones: []
    )
    let grouped = DeadlinesMerge.groupByDate(items)
    XCTAssertEqual(grouped["2026-09-05"]?.count, 2)
    XCTAssertEqual(grouped["2026-09-06"]?.count, 1)
    XCTAssertNil(grouped["2026-09-07"])
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
