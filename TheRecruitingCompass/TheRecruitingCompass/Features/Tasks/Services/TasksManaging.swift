import Foundation

protocol TasksManaging: Sendable {
  func fetchTasksWithStatus(gradeLevel: Int, athleteId: String) async throws -> [TaskWithStatus]
  /// Fetch tasks for all grades (9, 10, 11, 12) with completion status. Returns dictionary keyed by grade level.
  func fetchAllTasksWithStatus(athleteId: String) async throws -> [Int: [TaskWithStatus]]
  func updateTaskStatus(taskId: String, status: TaskStatus, userId: String) async throws -> AthleteTaskStatus
}
