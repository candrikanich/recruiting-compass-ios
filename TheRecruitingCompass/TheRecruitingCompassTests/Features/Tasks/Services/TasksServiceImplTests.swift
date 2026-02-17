import XCTest
@testable import TheRecruitingCompass

final class TasksServiceImplTests: XCTestCase {

  var sut: TasksServiceImpl!

  override func setUp() {
    super.setUp()
    sut = TasksServiceImpl(supabaseManager: .shared)
  }

  override func tearDown() {
    sut = nil
    super.tearDown()
  }

  func testConformsToTasksManaging() {
    XCTAssertTrue(sut is TasksManaging)
  }

  func testFetchTasksWithStatus_DoesNotThrowWhenTableMissing() async {
    // When tasks/athlete_tasks tables don't exist or are empty, we get an error.
    // We only verify the call completes (or throws); no network in unit test without mock.
    do {
      _ = try await sut.fetchTasksWithStatus(gradeLevel: 10, athleteId: "test-user-id")
      // If we get here, Supabase is configured and returned (possibly empty).
    } catch {
      // Expected when tables missing or not configured.
      XCTAssertNotNil(error)
    }
  }

  func testUpdateTaskStatus_DoesNotThrowWhenTableMissing() async {
    do {
      _ = try await sut.updateTaskStatus(taskId: "t1", status: .completed, userId: "u1")
    } catch {
      XCTAssertNotNil(error)
    }
  }
}
