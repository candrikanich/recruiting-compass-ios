import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TasksListViewModelTests: XCTestCase {
  var viewModel: TasksListViewModel!
  var mockService: MockTasksService!
  var mockAuthManager: MockAuthManager!
  var familyManager: FamilyManager!

  override func setUp() async throws {
    mockService = MockTasksService()
    mockAuthManager = MockAuthManager()
    mockAuthManager.setMockUser(User(
      id: "athlete-1",
      email: "a@test.com",
      emailConfirmedAt: nil,
      phone: nil,
      createdAt: "",
      updatedAt: "",
      role: .player
    ))
    familyManager = FamilyManager(
      familyService: MockFamilyService(),
      authManager: mockAuthManager
    )
    viewModel = TasksListViewModel(
      tasksService: mockService,
      authManager: mockAuthManager,
      familyManager: familyManager
    )
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockAuthManager = nil
    familyManager = nil
  }

  func testLoadTasks_Success() async {
    viewModel.graduationYear = 2027
    mockService.stubbedTasks = [
      TaskWithStatus(id: "t1", title: "Task 1", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false),
      TaskWithStatus(id: "t2", title: "Task 2", gradeLevel: 10, category: "c", required: false, athleteTask: AthleteTaskStatus(taskId: "t2", userId: "u", status: .completed, completedAt: nil), hasIncompletePrerequisites: false)
    ]

    await viewModel.loadTasks()

    XCTAssertEqual(viewModel.tasks.count, 2)
    XCTAssertEqual(viewModel.progressCompleted, 1)
    XCTAssertEqual(viewModel.progressTotal, 2)
    XCTAssertEqual(viewModel.progressPercentage, 50)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(mockService.fetchTasksCallCount, 1)
    XCTAssertEqual(mockService.lastFetchAthleteId, "athlete-1")
  }

  func testFilteredTasks_StatusFilter() async {
    mockService.stubbedTasks = [
      TaskWithStatus(id: "t1", title: "A", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false),
      TaskWithStatus(id: "t2", title: "B", gradeLevel: 10, category: "c", required: true, athleteTask: AthleteTaskStatus(taskId: "t2", userId: "u", status: .completed, completedAt: nil), hasIncompletePrerequisites: false)
    ]
    await viewModel.loadTasks()
    viewModel.setStatusFilter(.completed)

    let filtered = viewModel.filteredTasks
    XCTAssertEqual(filtered.count, 1)
    XCTAssertEqual(filtered.first?.id, "t2")
  }

  func testMarkComplete_LockedTask_DoesNotCallService() async {
    mockService.stubbedTasks = [
      TaskWithStatus(id: "t1", title: "Locked", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: true)
    ]
    await viewModel.loadTasks()

    await viewModel.markComplete(taskId: "t1")

    XCTAssertEqual(mockService.updateTaskStatusCallCount, 0)
  }

  func testMarkComplete_UnlockedTask_CallsService() async {
    mockService.stubbedTasks = [
      TaskWithStatus(id: "t1", title: "Unlocked", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false)
    ]
    await viewModel.loadTasks()

    await viewModel.markComplete(taskId: "t1")

    XCTAssertEqual(mockService.updateTaskStatusCallCount, 1)
    XCTAssertEqual(mockService.lastUpdateTaskId, "t1")
    XCTAssertEqual(mockService.lastUpdateStatus, .completed)
    XCTAssertTrue(viewModel.showSuccessMessage)
  }

  func testToggleExpanded() {
    viewModel.toggleExpanded(taskId: "t1")
    XCTAssertEqual(viewModel.expandedTaskId, "t1")
    viewModel.toggleExpanded(taskId: "t1")
    XCTAssertNil(viewModel.expandedTaskId)
  }

  // MARK: - Edge cases: empty, all completed, nil deadline

  func testProgress_EmptyList_ZeroPercentage() async {
    mockService.stubbedTasks = []
    await viewModel.loadTasks()
    XCTAssertEqual(viewModel.progressCompleted, 0)
    XCTAssertEqual(viewModel.progressTotal, 0)
    XCTAssertEqual(viewModel.progressPercentage, 0)
  }

  func testProgress_AllCompleted_100Percentage() async {
    mockService.stubbedTasks = [
      TaskWithStatus(id: "t1", title: "A", gradeLevel: 10, category: "c", required: true, athleteTask: AthleteTaskStatus(taskId: "t1", userId: "u", status: .completed, completedAt: nil), hasIncompletePrerequisites: false),
      TaskWithStatus(id: "t2", title: "B", gradeLevel: 10, category: "c", required: true, athleteTask: AthleteTaskStatus(taskId: "t2", userId: "u", status: .completed, completedAt: nil), hasIncompletePrerequisites: false)
    ]
    await viewModel.loadTasks()
    XCTAssertEqual(viewModel.progressCompleted, 2)
    XCTAssertEqual(viewModel.progressTotal, 2)
    XCTAssertEqual(viewModel.progressPercentage, 100)
  }

  func testLoadTasks_Error_SetsErrorMessage() async {
    mockService.shouldThrowFetchError = true
    await viewModel.loadTasks()
    XCTAssertTrue(viewModel.tasks.isEmpty)
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("Failed to load") ?? false)
  }

  func testFilteredTasks_Sorting_RequiredFirstThenUrgencyThenAlpha() async {
    let ref = Calendar.current.startOfDay(for: Date())
    let in3 = Calendar.current.date(byAdding: .day, value: 3, to: ref)!
    let in10 = Calendar.current.date(byAdding: .day, value: 10, to: ref)!
    mockService.stubbedTasks = [
      TaskWithStatus(id: "opt", title: "Optional", gradeLevel: 10, category: "c", required: false, deadlineDate: in3, hasIncompletePrerequisites: false),
      TaskWithStatus(id: "req-urgent", title: "Required Urgent", gradeLevel: 10, category: "c", required: true, deadlineDate: in3, hasIncompletePrerequisites: false),
      TaskWithStatus(id: "req-upcoming", title: "Required Upcoming", gradeLevel: 10, category: "c", required: true, deadlineDate: in10, hasIncompletePrerequisites: false)
    ]
    await viewModel.loadTasks()
    let filtered = viewModel.filteredTasks
    XCTAssertEqual(filtered.count, 3)
    XCTAssertTrue(filtered[0].required)
    XCTAssertTrue(filtered[1].required)
    XCTAssertFalse(filtered[2].required)
    XCTAssertEqual(filtered[0].deadlineUrgency, .urgent)
    XCTAssertEqual(filtered[1].deadlineUrgency, .upcoming)
  }

  func testFilterPersistence_AfterLoadRestoresFromUserDefaults() async {
    mockService.stubbedTasks = [
      TaskWithStatus(id: "t1", title: "T1", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false)
    ]
    await viewModel.loadTasks()
    viewModel.setStatusFilter(.completed)
    viewModel.setUrgencyFilter(.urgent)

    let keyStatus = "taskStatusFilter_athlete-1"
    let keyUrgency = "taskUrgencyFilter_athlete-1"
    XCTAssertEqual(UserDefaults.standard.string(forKey: keyStatus), TaskStatusFilter.completed.rawValue)
    XCTAssertEqual(UserDefaults.standard.string(forKey: keyUrgency), TaskUrgencyFilter.urgent.rawValue)

    UserDefaults.standard.removeObject(forKey: keyStatus)
    UserDefaults.standard.removeObject(forKey: keyUrgency)
  }

  func testMarkComplete_ParentMode_DoesNotCallService() async {
    let parentMember = FamilyMember(
      id: "parent-fm",
      userId: "parent-user",
      familyUnitId: "fu1",
      role: "parent",
      addedAt: nil,
      user: FamilyMemberUser(id: "parent-user", email: "p@test.com", fullName: "Parent", role: "parent")
    )
    let athleteMember = FamilyMember(
      id: "athlete-fm",
      userId: "athlete-1",
      familyUnitId: "fu1",
      role: "athlete",
      addedAt: nil,
      user: FamilyMemberUser(id: "athlete-1", email: "a@test.com", fullName: "Athlete", role: "athlete")
    )
    let mockFamily = MockFamilyService()
    mockFamily.stubbedCurrentMember = parentMember
    mockFamily.stubbedFamilyUnit = FamilyUnit(id: "fu1", playerUserId: "athlete-1", familyName: "Family", familyCode: "CODE", codeGeneratedAt: nil, createdAt: "", updatedAt: "", homeLatitude: nil, homeLongitude: nil)
    mockFamily.stubbedFamilyMembers = [parentMember, athleteMember]

    let fm = FamilyManager(familyService: mockFamily, authManager: mockAuthManager)
    await fm.loadFamilyData()
    fm.selectAthlete("athlete-fm")

    let vm = TasksListViewModel(tasksService: mockService, authManager: mockAuthManager, familyManager: fm)
    mockService.stubbedTasks = [
      TaskWithStatus(id: "t1", title: "T1", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false)
    ]
    await vm.loadTasks()
    XCTAssertTrue(vm.isViewingAsParent)

    await vm.markComplete(taskId: "t1")
    XCTAssertEqual(mockService.updateTaskStatusCallCount, 0)
  }
}
