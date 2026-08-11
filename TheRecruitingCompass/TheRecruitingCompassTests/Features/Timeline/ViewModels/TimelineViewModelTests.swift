import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TimelineViewModelTests: XCTestCase {
  nonisolated deinit {}

  var viewModel: TimelineViewModel!
  var mockTasksService: MockTasksService!
  var mockAPIService: MockTimelineAPIService!
  var mockPreferenceManager: MockPreferenceManager!
  var mockAuthManager: MockAuthManager!
  var familyManager: FamilyManager!

  override func setUp() async throws {
    mockTasksService = MockTasksService()
    mockAPIService = MockTimelineAPIService()
    mockPreferenceManager = MockPreferenceManager()
    mockAuthManager = MockAuthManager()
    mockAuthManager.setMockUser(userMock(id: "solo-user-1"))
    familyManager = FamilyManager(familyService: MockFamilyService(), authManager: mockAuthManager)

    viewModel = TimelineViewModel(
      tasksService: mockTasksService,
      apiService: mockAPIService,
      preferenceService: mockPreferenceManager,
      authManager: mockAuthManager,
      familyManager: familyManager
    )
  }

  override func tearDown() {
    viewModel = nil
    mockTasksService = nil
    mockAPIService = nil
    mockPreferenceManager = nil
    mockAuthManager = nil
    familyManager = nil
  }

  // MARK: - Athlete-ID Resolution (guards the Phase 1 selectedAthlete.userId pattern)

  func testCurrentAthleteId_soloUser_usesSignedInUserId() {
    XCTAssertEqual(viewModel.currentAthleteId, "solo-user-1")
  }

  func testLoad_parentViewingAthlete_usesAthleteUserId_notParentId() async {
    let parentAuth = MockAuthManager()
    let parentFamilyManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: parentAuth)
    let sut = TimelineViewModel(
      tasksService: mockTasksService,
      apiService: mockAPIService,
      preferenceService: mockPreferenceManager,
      authManager: parentAuth,
      familyManager: parentFamilyManager
    )

    XCTAssertEqual(sut.currentAthleteId, ParentViewingAthleteFixture.athleteUserId)
    XCTAssertTrue(sut.isViewingAsParent)

    await sut.load()

    // The athlete id drives the local tasks fetch; the endpoints resolve
    // viewer→athlete server-side, so they receive only the bearer token.
    XCTAssertEqual(mockTasksService.lastFetchAthleteId, ParentViewingAthleteFixture.athleteUserId)
    XCTAssertEqual(mockAPIService.phaseCallCount, 1)
    XCTAssertEqual(mockAPIService.statusCallCount, 1)
  }

  // MARK: - load()

  func testLoad_noAthleteId_setsErrorAndSkipsFetch() async {
    mockAuthManager.user = nil

    await viewModel.load()

    XCTAssertEqual(viewModel.errorMessage, "Unable to load timeline.")
    XCTAssertEqual(mockAPIService.phaseCallCount, 0)
    XCTAssertEqual(mockAPIService.statusCallCount, 0)
  }

  func testLoad_success_populatesAllState() async {
    mockPreferenceManager.fetchPreferencesResult = .success(PlayerDetails(graduationYear: 2027))
    mockTasksService.stubbedTasksByGrade = [
      9: [makeTask(id: "t1", gradeLevel: 9, required: true)],
      10: [], 11: [], 12: []
    ]
    mockAPIService.stubbedPhase = .sophomore
    mockAPIService.stubbedCanAdvance = true
    mockAPIService.stubbedStatusScore = 72
    mockAPIService.stubbedStatusLabel = .onTrack

    await viewModel.load()

    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertEqual(viewModel.graduationYear, 2027)
    XCTAssertEqual(viewModel.tasksByGrade[9]?.count, 1)
    XCTAssertEqual(viewModel.currentPhase, .sophomore)
    XCTAssertTrue(viewModel.canAdvancePhase)
    XCTAssertEqual(viewModel.statusScore?.score, 72)
    XCTAssertEqual(viewModel.statusLabel, .onTrack)
    XCTAssertEqual(viewModel.statusScoreValue, 72)
  }

  func testLoad_setsExpandedPhaseToCurrentPhase_whenNotAlreadySet() async {
    viewModel.expandedPhaseGrade = nil
    mockAPIService.stubbedPhase = .junior

    await viewModel.load()

    XCTAssertEqual(viewModel.expandedPhaseGrade, TimelinePhase.junior.gradeLevel)
  }

  func testLoad_preservesExplicitExpandedPhase() async {
    viewModel.setExpandedPhase(grade: 11)
    mockAPIService.stubbedPhase = .senior

    await viewModel.load()

    XCTAssertEqual(viewModel.expandedPhaseGrade, 11)
  }

  func testLoad_phaseServiceThrows_setsErrorMessage() async {
    mockAPIService.shouldThrowError = true

    await viewModel.load()

    XCTAssertEqual(viewModel.errorMessage, "Failed to load timeline. Please try again.")
  }

  func testLoad_tasksServiceThrows_setsErrorMessage() async {
    mockTasksService.shouldThrowFetchError = true

    await viewModel.load()

    XCTAssertEqual(viewModel.errorMessage, "Failed to load timeline. Please try again.")
  }

  func testLoad_setsCurrentTaskFromWhatMattersNowFirstItem() async {
    mockAPIService.stubbedWhatMatters = [
      WhatMattersItem(
        taskId: "wm1",
        title: "Take Official SAT or ACT",
        whyItMatters: "Required for eligibility.",
        category: "academic",
        priority: 10,
        isRequired: true
      ),
      WhatMattersItem(
        taskId: "wm2",
        title: "Second priority",
        whyItMatters: "Lower.",
        category: "training",
        priority: 5,
        isRequired: true
      )
    ]

    await viewModel.load()

    XCTAssertEqual(viewModel.currentTask?.taskId, "wm1")
    XCTAssertEqual(viewModel.currentTask?.title, "Take Official SAT or ACT")
    XCTAssertEqual(mockAPIService.whatMattersCallCount, 1)
  }

  func testLoad_emptyWhatMattersNow_leavesCurrentTaskNil() async {
    mockAPIService.stubbedWhatMatters = []

    await viewModel.load()

    XCTAssertNil(viewModel.currentTask)
  }

  // MARK: - Computed Properties

  func testAllTasks_flattensAcrossGrades() async {
    mockTasksService.stubbedTasksByGrade = [
      9: [makeTask(id: "t1", gradeLevel: 9, required: true)],
      10: [makeTask(id: "t2", gradeLevel: 10, required: true)],
      11: [], 12: []
    ]

    await viewModel.load()

    XCTAssertEqual(viewModel.allTasks.count, 2)
    XCTAssertEqual(viewModel.taskTotalCount, 2)
  }

  func testTaskCompletedCount_countsOnlyCompleted() async {
    mockTasksService.stubbedTasksByGrade = [
      9: [
        makeTask(id: "t1", gradeLevel: 9, required: true, status: .completed),
        makeTask(id: "t2", gradeLevel: 9, required: true, status: .notStarted)
      ]
    ]

    await viewModel.load()

    XCTAssertEqual(viewModel.taskCompletedCount, 1)
  }

  func testMilestonesCounts_readFromMilestoneProgress() async {
    mockAPIService.stubbedMilestoneProgress = MilestoneProgress(
      phase: .freshman,
      required: ["m1", "m2", "m3"],
      completed: ["m1"],
      remaining: ["m2", "m3"],
      percentComplete: 33
    )

    await viewModel.load()

    XCTAssertEqual(viewModel.milestonesCompletedCount, 1)
    XCTAssertEqual(viewModel.milestonesTotalCount, 3)
  }

  func testStatusLabelAndScore_nilBeforeLoad() {
    XCTAssertNil(viewModel.statusLabel)
    XCTAssertEqual(viewModel.statusScoreValue, 0)
  }

  // MARK: - Phase Expansion

  func testTogglePhaseExpanded_collapsesWhenAlreadyExpanded() {
    viewModel.expandedPhaseGrade = 10
    viewModel.togglePhaseExpanded(grade: 10)
    XCTAssertNil(viewModel.expandedPhaseGrade)
  }

  func testTogglePhaseExpanded_expandsDifferentGrade() {
    viewModel.expandedPhaseGrade = 9
    viewModel.togglePhaseExpanded(grade: 11)
    XCTAssertEqual(viewModel.expandedPhaseGrade, 11)
  }

  // MARK: - markComplete

  func testMarkComplete_viewingAsParent_isNoOp() async {
    let parentAuth = MockAuthManager()
    let parentFamilyManager = ParentViewingAthleteFixture.makeFamilyManager(authManager: parentAuth)
    let sut = TimelineViewModel(
      tasksService: mockTasksService,
      apiService: mockAPIService,
      preferenceService: mockPreferenceManager,
      authManager: parentAuth,
      familyManager: parentFamilyManager
    )
    mockTasksService.stubbedTasksByGrade = [9: [makeTask(id: "t1", gradeLevel: 9, required: true)]]
    await sut.load()

    await sut.markComplete(taskId: "t1")

    XCTAssertEqual(mockTasksService.updateTaskStatusCallCount, 0)
  }

  func testMarkComplete_taskNotFound_isNoOp() async {
    await viewModel.markComplete(taskId: "nonexistent")
    XCTAssertEqual(mockTasksService.updateTaskStatusCallCount, 0)
  }

  func testMarkComplete_lockedTask_isNoOp() async {
    mockTasksService.stubbedTasksByGrade = [
      9: [makeTask(id: "t1", gradeLevel: 9, required: true, isLocked: true)]
    ]
    await viewModel.load()

    await viewModel.markComplete(taskId: "t1")

    XCTAssertEqual(mockTasksService.updateTaskStatusCallCount, 0)
  }

  func testMarkComplete_success_updatesStatusAndShowsSuccess() async {
    mockTasksService.stubbedTasksByGrade = [9: [makeTask(id: "t1", gradeLevel: 9, required: true)]]
    await viewModel.load()

    await viewModel.markComplete(taskId: "t1")

    XCTAssertEqual(mockTasksService.updateTaskStatusCallCount, 1)
    XCTAssertEqual(mockTasksService.lastUpdateTaskId, "t1")
    XCTAssertEqual(mockTasksService.lastUpdateStatus, .completed)
    XCTAssertEqual(mockTasksService.lastUpdateUserId, "solo-user-1")
    XCTAssertTrue(viewModel.showSuccessMessage)
  }

  func testMarkComplete_serviceThrows_setsErrorMessage() async {
    mockTasksService.stubbedTasksByGrade = [9: [makeTask(id: "t1", gradeLevel: 9, required: true)]]
    await viewModel.load()
    mockTasksService.shouldThrowUpdateError = true

    await viewModel.markComplete(taskId: "t1")

    XCTAssertEqual(viewModel.errorMessage, "Failed to update task. Please try again.")
    XCTAssertFalse(viewModel.showSuccessMessage)
  }

  func testClearSuccessMessage_resetsFlag() {
    viewModel.showSuccessMessage = true
    viewModel.clearSuccessMessage()
    XCTAssertFalse(viewModel.showSuccessMessage)
  }

  // MARK: - Helpers

  private func userMock(id: String) -> User {
    User(
      id: id,
      email: "test@example.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      role: .player
    )
  }

  private func makeTask(
    id: String,
    gradeLevel: Int,
    required: Bool,
    status: TaskStatus = .notStarted,
    isLocked: Bool = false
  ) -> TaskWithStatus {
    TaskWithStatus(
      id: id,
      title: "Task \(id)",
      gradeLevel: gradeLevel,
      category: "general",
      required: required,
      athleteTask: AthleteTaskStatus(taskId: id, userId: "solo-user-1", status: status, completedAt: nil),
      hasIncompletePrerequisites: isLocked
    )
  }
}
