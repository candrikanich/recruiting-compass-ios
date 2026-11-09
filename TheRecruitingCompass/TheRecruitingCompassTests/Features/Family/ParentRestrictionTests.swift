import XCTest
@testable import TheRecruitingCompass

@MainActor
final class ParentRestrictionTests: XCTestCase {
  nonisolated deinit {}

  func testCompleteTaskMessage_namesAthleteAndNeverReadsAsAnError() {
    let message = ParentRestriction.completeTaskMessage(athleteName: "Jordan")
    XCTAssertEqual(message, "Only Jordan can mark tasks complete. You can still add notes and documents.")
    XCTAssertFalse(message.lowercased().contains("denied"))
  }

  func testBannerDetail_saysEditsAreSharedAndNotReadOnly() {
    let detail = ParentRestriction.bannerDetail(athleteName: "Jordan")
    XCTAssertTrue(detail.contains("shared with the whole family"))
    XCTAssertFalse(detail.lowercased().contains("read-only"))
  }

  func testTimelineMarkComplete_parent_isRestrictedWithFriendlyNotice() async {
    let tasks = MockTasksService()
    let auth = MockAuthManager()
    let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    let sut = TimelineViewModel(
      tasksService: tasks,
      apiService: MockTimelineAPIService(),
      preferenceService: MockPreferenceManager(),
      authManager: auth,
      familyManager: family
    )
    tasks.stubbedTasksByGrade = [9: [TaskWithStatus(
      id: "t1", title: "T", gradeLevel: 9, category: "c", required: true, hasIncompletePrerequisites: false)]]
    await sut.load()

    await sut.markComplete(taskId: "t1")

    XCTAssertEqual(tasks.updateTaskStatusCallCount, 0)
    XCTAssertEqual(sut.restrictionNotice, ParentRestriction.completeTaskMessage(athleteName: "your athlete"))
    XCTAssertNil(sut.errorMessage)
  }

  func testTasksListMarkComplete_parent_surfacesSameNotice() async {
    let tasks = MockTasksService()
    let auth = MockAuthManager()
    let family = ParentViewingAthleteFixture.makeFamilyManager(authManager: auth)
    let sut = TasksListViewModel(
      tasksService: tasks, authManager: auth, familyManager: family, cache: InMemoryCache(),
      preferenceService: MockPreferenceService())
    tasks.stubbedTasks = [TaskWithStatus(
      id: "t1", title: "T", gradeLevel: 10, category: "c", required: true, hasIncompletePrerequisites: false)]
    await sut.loadTasks()

    await sut.markComplete(taskId: "t1")

    XCTAssertEqual(tasks.updateTaskStatusCallCount, 0)
    XCTAssertEqual(sut.restrictionNotice, ParentRestriction.completeTaskMessage(athleteName: "your athlete"))
  }

  func testTimelineMarkComplete_athlete_stillCompletes() async {
    let tasks = MockTasksService()
    let auth = MockAuthManager()
    auth.setMockUser(User(
      id: "athlete-solo", email: "a@example.com", emailConfirmedAt: nil, createdAt: "", updatedAt: "", role: .player))
    let sut = TimelineViewModel(
      tasksService: tasks,
      apiService: MockTimelineAPIService(),
      preferenceService: MockPreferenceManager(),
      authManager: auth,
      familyManager: FamilyManager(familyService: MockFamilyService(), authManager: auth)
    )
    tasks.stubbedTasksByGrade = [9: [TaskWithStatus(
      id: "t1", title: "T", gradeLevel: 9, category: "c", required: true, hasIncompletePrerequisites: false)]]
    await sut.load()

    await sut.markComplete(taskId: "t1")

    XCTAssertEqual(tasks.updateTaskStatusCallCount, 1)
    XCTAssertNil(sut.restrictionNotice)
  }
}
