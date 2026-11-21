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

/// Call N waits on latches[N]; later calls pass straight through.
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

/// A full Timeline load for athlete A that lands after the parent switched to athlete B must not write anything.
@MainActor
final class TimelineViewModelStaleTasksLoadTests: XCTestCase {
  nonisolated deinit {}

  private var api: MockTimelineAPIService!
  private var tasks: MockTasksService!
  private var prefs: MockPreferenceManager!
  private var family: FamilyManager!
  private var sut: TimelineViewModel!

  override func setUp() async throws {
    api = MockTimelineAPIService()
    tasks = MockTasksService()
    prefs = MockPreferenceManager()
    let auth = MockAuthManager()
    family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    sut = TimelineViewModel(
      tasksService: tasks,
      apiService: api,
      preferenceService: prefs,
      authManager: auth,
      familyManager: family,
      dashboardService: MockDashboardService()
    )
  }

  private func task(_ id: String) -> TaskWithStatus {
    TaskWithStatus(
      id: id, title: id, gradeLevel: 9, category: "academic", required: true,
      deadlineDate: nil, athleteTask: nil, hasIncompletePrerequisites: false
    )
  }

  private func details(graduationYear: Int) -> PlayerDetails {
    var details = PlayerDetails()
    details.graduationYear = graduationYear
    return details
  }

  private func waitFor(_ condition: () -> Bool) async {
    for _ in 0..<10_000 where !condition() { await Task.yield() }
    XCTAssertTrue(condition(), "timed out waiting")
  }

  /// Starts A's load held at the preferences read (or the tasks fetch), then switches to B and loads B to completion.
  private func startStaleLoadForA(gate: OrderedGate, holdingTasks: Bool = false) async -> Task<Void, Never> {
    if holdingTasks {
      tasks.fetchAllTasksGate = { await gate.pass() }
    } else {
      prefs.fetchPreferencesGate = { await gate.pass() }
    }
    tasks.stubbedTasksByGrade = [9: [task("A1")], 10: [], 11: [], 12: []]
    prefs.fetchPreferencesResult = .success(details(graduationYear: 2027))
    let loadA = Task { await sut.load() }
    await waitFor { tasks.fetchAllTasksCallCount == 1 && prefs.fetchPreferencesCalls.count == 1 }
    if holdingTasks { await waitFor { sut.graduationYear == 2027 } }

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    tasks.stubbedTasksByGrade = [9: [task("B1")], 10: [], 11: [], 12: []]
    prefs.fetchPreferencesResult = .success(details(graduationYear: 2028))
    await sut.load()
    return loadA
  }

  func testStaleLoad_landingAfterSwitch_doesNotOverwriteTheNewAthletesTimeline() async {
    let gate = OrderedGate(1)
    let loadA = await startStaleLoadForA(gate: gate)
    sut.setExpandedPhase(grade: nil)

    await gate.latches[0].release()
    await loadA.value

    XCTAssertEqual(sut.allTasks.map(\.id), ["B1"], "athlete A's tasks shown for athlete B")
    XCTAssertEqual(sut.graduationYear, 2028)
    XCTAssertNil(sut.expandedPhaseGrade)
    XCTAssertNil(sut.errorMessage)
  }

  /// A's preferences already resolved; it is held at the tasks fetch when the switch happens.
  func testStaleLoad_heldAtTheTasksFetch_doesNotOverwriteTheNewAthletesTasksOrExpandedPhase() async {
    let gate = OrderedGate(1)
    let loadA = await startStaleLoadForA(gate: gate, holdingTasks: true)
    sut.setExpandedPhase(grade: nil)

    await gate.latches[0].release()
    await loadA.value

    XCTAssertEqual(sut.allTasks.map(\.id), ["B1"], "athlete A's tasks shown for athlete B")
    XCTAssertNil(sut.expandedPhaseGrade)
    XCTAssertNil(sut.errorMessage)
  }

  /// A's tasks and preferences landed; it is held at the summary fetch when the switch happens.
  func testStaleLoad_heldAtTheSummaryFetch_doesNotSetTheNewAthletesExpandedPhase() async {
    let gate = OrderedGate(1)
    api.fetchPhaseGate = { await gate.pass() }
    tasks.stubbedTasksByGrade = [9: [task("A1")], 10: [], 11: [], 12: []]
    let loadA = Task { await sut.load() }
    await waitFor { api.phaseCallCount == 1 && sut.allTasks.map(\.id) == ["A1"] }

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    tasks.stubbedTasksByGrade = [9: [task("B1")], 10: [], 11: [], 12: []]
    await sut.load()
    sut.setExpandedPhase(grade: nil)

    await gate.latches[0].release()
    await loadA.value

    XCTAssertNil(sut.expandedPhaseGrade, "athlete A's phase expanded on athlete B's Timeline")
    XCTAssertEqual(sut.allTasks.map(\.id), ["B1"])
  }

  func testStaleLoad_failingAfterSwitch_doesNotSetTheNewAthletesError() async {
    let gate = OrderedGate(1)
    let loadA = await startStaleLoadForA(gate: gate, holdingTasks: true)
    tasks.shouldThrowFetchError = true

    await gate.latches[0].release()
    await loadA.value

    XCTAssertNil(sut.errorMessage, "athlete A's failure shown on athlete B's Timeline")
    XCTAssertEqual(sut.allTasks.map(\.id), ["B1"])
  }

  func testStaleLoad_finishingWhileTheNewAthletesLoadRuns_doesNotClearIsLoading() async {
    let gate = OrderedGate(2)
    tasks.fetchAllTasksGate = { await gate.pass() }
    let loadA = Task { await sut.load() }
    await waitFor { tasks.fetchAllTasksCallCount == 1 }

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    let loadB = Task { await sut.load() }
    await waitFor { tasks.fetchAllTasksCallCount == 2 }

    await gate.latches[0].release()
    await loadA.value
    XCTAssertTrue(sut.isLoading, "athlete A's load finished and cleared athlete B's loading state")

    await gate.latches[1].release()
    await loadB.value
    XCTAssertFalse(sut.isLoading)
  }

  func testStaleSummaryLoad_failingAfterSwitch_doesNotSetTheNewAthletesError() async {
    let api = MockTimelineAPIService()
    let gate = OrderedGate(1)
    api.fetchPhaseGate = { await gate.pass() }
    let auth = MockAuthManager()
    let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    let sut = TimelineViewModel(
      tasksService: tasks, apiService: api, preferenceService: prefs, authManager: auth,
      familyManager: family, dashboardService: MockDashboardService()
    )
    let loadA = Task { await sut.loadSummary() }
    await waitFor { api.phaseCallCount == 1 }

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    await sut.loadSummary()
    api.shouldThrowError = true
    await gate.latches[0].release()
    await loadA.value

    XCTAssertNil(sut.errorMessage, "athlete A's failure shown on athlete B's Timeline")
  }

  func testStaleSummaryLoad_finishingWhileTheNewAthletesLoadRuns_doesNotClearIsLoading() async {
    let api = MockTimelineAPIService()
    let gate = OrderedGate(2)
    api.fetchPhaseGate = { await gate.pass() }
    let auth = MockAuthManager()
    let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    let sut = TimelineViewModel(
      tasksService: tasks, apiService: api, preferenceService: prefs, authManager: auth,
      familyManager: family, dashboardService: MockDashboardService()
    )
    let loadA = Task { await sut.loadSummary() }
    await waitFor { api.phaseCallCount == 1 }

    ParentViewingAthleteFixture.selectSecondAthlete(in: family)
    let loadB = Task { await sut.loadSummary() }
    await waitFor { api.phaseCallCount == 2 }

    await gate.latches[0].release()
    await loadA.value
    XCTAssertTrue(sut.isLoading, "athlete A's summary load cleared athlete B's loading state")

    await gate.latches[1].release()
    await loadB.value
    XCTAssertFalse(sut.isLoading)
  }
}
