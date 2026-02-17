import Foundation
@testable import TheRecruitingCompass

final class MockTasksService: TasksManaging, @unchecked Sendable {
  var stubbedTasks: [TaskWithStatus] = []
  var stubbedAthleteTaskStatus: AthleteTaskStatus?
  var shouldThrowFetchError = false
  var shouldThrowUpdateError = false

  var fetchTasksCallCount = 0
  var updateTaskStatusCallCount = 0
  var lastFetchGradeLevel: Int?
  var lastFetchAthleteId: String?
  var lastUpdateTaskId: String?
  var lastUpdateStatus: TaskStatus?
  var lastUpdateUserId: String?

  func fetchTasksWithStatus(gradeLevel: Int, athleteId: String) async throws -> [TaskWithStatus] {
    fetchTasksCallCount += 1
    lastFetchGradeLevel = gradeLevel
    lastFetchAthleteId = athleteId
    if shouldThrowFetchError {
      throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
    }
    return stubbedTasks
  }

  func updateTaskStatus(taskId: String, status: TaskStatus, userId: String) async throws -> AthleteTaskStatus {
    updateTaskStatusCallCount += 1
    lastUpdateTaskId = taskId
    lastUpdateStatus = status
    lastUpdateUserId = userId
    if shouldThrowUpdateError {
      throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Update failed"])
    }
    return stubbedAthleteTaskStatus ?? AthleteTaskStatus(taskId: taskId, userId: userId, status: status, completedAt: status == .completed ? Date() : nil)
  }
}
