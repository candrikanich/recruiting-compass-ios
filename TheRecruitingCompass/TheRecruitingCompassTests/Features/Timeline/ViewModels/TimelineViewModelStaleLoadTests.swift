import os
import XCTest
@testable import TheRecruitingCompass

private actor Latch {
  private var continuation: CheckedContinuation<Void, Never>?
  private var released = false
  func wait() async {
    if released { return }
    await withCheckedContinuation { continuation = $0 }
  }
  func release() {
    released = true
    continuation?.resume()
    continuation = nil
  }
}

/// fetchPhase call N waits on latches[N]; later calls pass straight through.
private final class OrderedGate: @unchecked Sendable {
  private let counter = OSAllocatedUnfairLock(initialState: 0)
  let latches: [Latch]
  init(_ count: Int) { latches = (0..<count).map { _ in Latch() } }
  func pass() async {
    let index = counter.withLock { value -> Int in
      defer { value += 1 }
      return value
    }
    if index < latches.count { await latches[index].wait() }
  }
}

@MainActor
final class TimelineViewModelStaleLoadTests: XCTestCase {
  nonisolated deinit {}

  private var api: MockTimelineAPIService!
  private var family: FamilyManager!
  private var sut: TimelineViewModel!

  override func setUp() async throws {
    api = MockTimelineAPIService()
    let auth = MockAuthManager()
    family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    sut = TimelineViewModel(
      tasksService: MockTasksService(),
      apiService: api,
      preferenceService: MockPreferenceManager(),
      authManager: auth,
      familyManager: family,
      dashboardService: MockDashboardService()
    )
  }

  private func step(_ id: String) -> WhatMattersItem {
    WhatMattersItem(taskId: id, title: id, whyItMatters: "why", category: "c", priority: 1, isRequired: true)
  }

  private func waitFor(_ condition: () -> Bool) async {
    for _ in 0..<10_000 where !condition() { await Task.yield() }
    XCTAssertTrue(condition(), "timed out waiting")
  }

  /// Athlete A's load is still in flight when the parent switches to B; B loads fine; A's answer lands last.
  func testStaleLoad_landingAfterSwitch_doesNotShowThePreviousAthletesSteps() async {
    let gate = OrderedGate(1)
    api.fetchPhaseGate = { await gate.pass() }
    api.stubbedWhatMatters = [step("A1")]
    let loadA = Task { await sut.loadSummary() }
    await waitFor { api.phaseCallCount == 1 && api.whatMattersCallCount == 1 }

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    api.stubbedWhatMatters = [step("B1")]
    await sut.loadSummary()
    XCTAssertEqual(sut.nextSteps.map(\.taskId), ["B1"])

    await gate.latches[0].release()
    await loadA.value

    XCTAssertEqual(sut.currentAthleteId, ParentViewingAthleteFixture.secondAthleteUserId)
    XCTAssertEqual(sut.nextSteps.map(\.taskId), ["B1"], "athlete A's steps shown while athlete B is selected")
  }

  /// Same, but B's phase fetch fails: the card must say it couldn't load, not show A's steps as B's.
  func testStaleLoad_landingAfterTheNewAthletesFetchFailed_doesNotShowThePreviousAthletesSteps() async {
    let gate = OrderedGate(1)
    api.fetchPhaseGate = { await gate.pass() }
    api.stubbedWhatMatters = [step("A1")]
    let loadA = Task { await sut.loadSummary() }
    await waitFor { api.phaseCallCount == 1 && api.whatMattersCallCount == 1 }

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    api.shouldThrowError = true
    await sut.loadSummary()
    XCTAssertFalse(sut.isPhaseResolved)

    api.shouldThrowError = false
    await gate.latches[0].release()
    await loadA.value

    XCTAssertTrue(sut.nextSteps.isEmpty, "athlete A's steps shown for athlete B: \(sut.nextSteps.map(\.taskId))")
    XCTAssertFalse(sut.isPhaseResolved)
  }

  /// Single athlete, no switch: success, then a refresh whose phase fetch fails. Items are not cleared here.
  func testRefreshFailureAfterSuccess_sameAthlete_nextStepsEmpty() async {
    api.stubbedWhatMatters = [step("1")]
    await sut.loadSummary()
    api.shouldThrowError = true
    await sut.refresh()

    XCTAssertFalse(sut.isPhaseResolved)
    XCTAssertTrue(sut.nextSteps.isEmpty)
  }
}
