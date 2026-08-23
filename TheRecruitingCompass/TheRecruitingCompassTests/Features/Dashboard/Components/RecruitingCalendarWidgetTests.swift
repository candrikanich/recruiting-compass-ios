import XCTest
@testable import TheRecruitingCompass

@MainActor
final class RecruitingCalendarWidgetTests: XCTestCase {
  nonisolated deinit {}

  func test_currentPeriod_baseball_july4_isDead_notContact() {
    let cal = RecruitingCalendar.calendar(sport: "Baseball", division: "D1")
    let period = RecruitingCalendarWidget.currentPeriod(in: cal.periods, todayISO: "2027-07-04")
    XCTAssertEqual(period?.type, .dead)
  }

  func test_currentPeriod_baseball_thanksgiving_isRecruitingShutdown_notQuiet() {
    let cal = RecruitingCalendar.calendar(sport: "Baseball", division: "D1")
    let period = RecruitingCalendarWidget.currentPeriod(in: cal.periods, todayISO: "2026-11-25")
    XCTAssertEqual(period?.type, .recruitingShutdown)
  }

  func test_isStale_afterSeasonEnd_true() {
    XCTAssertTrue(RecruitingCalendarWidget.isStale(todayISO: "2027-08-01"))
  }

  func test_isStale_beforeSeasonEnd_false() {
    XCTAssertFalse(RecruitingCalendarWidget.isStale(todayISO: "2027-01-01"))
  }
}
