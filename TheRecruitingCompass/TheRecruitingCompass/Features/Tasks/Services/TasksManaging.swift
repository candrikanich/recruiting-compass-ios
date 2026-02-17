import Foundation

protocol TasksManaging: Sendable {
  func fetchTasksWithStatus(gradeLevel: Int, athleteId: String) async throws -> [TaskWithStatus]
  func updateTaskStatus(taskId: String, status: TaskStatus, userId: String) async throws -> AthleteTaskStatus
}
