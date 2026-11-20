import XCTest
@testable import TheRecruitingCompass

/// Each Home event that can change the first-run state re-reads the signals (and the dashboard data it needs).
/// `DashboardView` only forwards the event, which the QA real-flow run covers.
@MainActor
final class DashboardRefreshTriggersTests: XCTestCase {
  nonisolated deinit {}

  private var calls: [String] = []

  private func makeSut() -> DashboardRefreshTriggers {
    DashboardRefreshTriggers(
      fetchDashboardData: { [weak self] in self?.calls.append("fetch") },
      refreshDashboard: { [weak self] in self?.calls.append("refresh") },
      refreshFirstRunSignals: { [weak self] in self?.calls.append("signals") },
      refreshFirstRunSignalsIfIdle: { [weak self] in self?.calls.append("signalsIfIdle") }
    )
  }

  func testScreenAppeared_rereadsTheSignalsOnlyWhenIdle() async {
    await makeSut().screenAppeared()
    XCTAssertEqual(calls, ["signalsIfIdle"])
  }

  func testAddSchoolSheetDismissed_fetchesDashboardAndRefreshesSignals() async {
    await makeSut().addSchoolSheetDismissed()
    XCTAssertEqual(Set(calls), ["fetch", "signals"])
    XCTAssertEqual(calls.count, 2)
  }

  func testCoachContacted_fetchesDashboardAndRefreshesSignals() async {
    await makeSut().coachContacted()
    XCTAssertEqual(Set(calls), ["fetch", "signals"])
    XCTAssertEqual(calls.count, 2)
  }

  func testActionCompleted_fetchesDashboardAndRefreshesSignals() async {
    await makeSut().actionCompleted()
    XCTAssertEqual(Set(calls), ["fetch", "signals"])
    XCTAssertEqual(calls.count, 2)
  }

  func testRealtimeEventReceived_refreshesDashboardAndSignals() async {
    await makeSut().realtimeEventReceived()
    XCTAssertEqual(Set(calls), ["refresh", "signals"])
    XCTAssertEqual(calls.count, 2)
  }
}
