import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "TasksService")

/// Raw row from Supabase `task` table (snake_case columns).
private struct TaskRow: Codable {
  let id: String
  let title: String
  let description: String?
  let gradeLevel: Int
  let category: String
  let division: String?
  let required: Bool
  let deadlineDate: String?
  let whyItMatters: String?
  let failureRisk: String?
  let dependencyTaskIds: [String]?

  enum CodingKeys: String, CodingKey {
    case id, title, description, category, division, required
    case gradeLevel = "grade_level"
    case deadlineDate = "deadline_date"
    case whyItMatters = "why_it_matters"
    case failureRisk = "failure_risk"
    case dependencyTaskIds = "dependency_task_ids"
  }
}

/// Payload for upserting athlete_task (snake_case for API).
private struct AthleteTaskUpsert: Encodable {
  let taskId: String
  let athleteId: String
  let status: String
  let completedAt: String?

  enum CodingKeys: String, CodingKey {
    case taskId = "task_id"
    case athleteId = "athlete_id"
    case status
    case completedAt = "completed_at"
  }
}

private let taskIsoFormatterFractional: ISO8601DateFormatter = {
  let f = ISO8601DateFormatter()
  f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return f
}()

private let taskIsoFormatterBasic = ISO8601DateFormatter()

private let taskDateOnlyFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd"
  return f
}()

private func parseTaskDate(_ string: String) -> Date? {
  taskIsoFormatterFractional.date(from: string)
    ?? taskIsoFormatterBasic.date(from: string)
    ?? taskDateOnlyFormatter.date(from: string)
}

final class TasksServiceImpl: TasksManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchTasksWithStatus(gradeLevel: Int, athleteId: String) async throws -> [TaskWithStatus] {
    logger.info("Fetching tasks for grade \(gradeLevel), athlete \(athleteId)")

    async let rowsResult: [TaskRow] = supabaseManager.client
      .from("task")
      .select()
      .eq("grade_level", value: gradeLevel)
      .order("id", ascending: true)
      .execute()
      .value

    async let athleteTasksResult: [AthleteTaskStatus] = supabaseManager.client
      .from("athlete_task")
      .select()
      .eq("athlete_id", value: athleteId)
      .execute()
      .value

    let (rows, athleteTasks) = try await (rowsResult, athleteTasksResult)
    let athleteTaskByTaskId = Dictionary(uniqueKeysWithValues: athleteTasks.map { ($0.taskId, $0) })

    let taskSummariesById: [String: TaskSummary] = Dictionary(
      uniqueKeysWithValues: rows.map { ($0.id, TaskSummary(id: $0.id, title: $0.title)) }
    )

    var result: [TaskWithStatus] = []
    for row in rows {
      let athleteTask = athleteTaskByTaskId[row.id]
      let prerequisiteTasks = (row.dependencyTaskIds ?? []).compactMap { taskSummariesById[$0] }
      let completedTaskIds = Set(athleteTasks.filter { $0.status == .completed }.map(\.taskId))
      let hasIncompletePrerequisites = (row.dependencyTaskIds ?? []).contains { !completedTaskIds.contains($0) }

      let deadlineDate: Date? = row.deadlineDate.flatMap { parseTaskDate($0) }

      let task = TaskWithStatus(
        id: row.id,
        title: row.title,
        description: row.description,
        gradeLevel: row.gradeLevel,
        category: row.category,
        division: row.division,
        required: row.required,
        deadlineDate: deadlineDate,
        whyItMatters: row.whyItMatters,
        failureRisk: row.failureRisk,
        dependencyTaskIds: row.dependencyTaskIds ?? [],
        athleteTask: athleteTask,
        prerequisiteTasks: prerequisiteTasks,
        hasIncompletePrerequisites: hasIncompletePrerequisites
      )
      result.append(task)
    }

    logger.info("Fetched \(result.count) tasks with status")
    return result
  }

  func fetchAllTasksWithStatus(athleteId: String) async throws -> [Int: [TaskWithStatus]] {
    let grades = [9, 10, 11, 12]
    var result: [Int: [TaskWithStatus]] = [:]
    for grade in grades {
      let tasks = try await fetchTasksWithStatus(gradeLevel: grade, athleteId: athleteId)
      result[grade] = tasks
    }
    logger.info("Fetched tasks for all grades, total: \(result.values.flatMap { $0 }.count)")
    return result
  }

  func updateTaskStatus(taskId: String, status: TaskStatus, userId: String) async throws -> AthleteTaskStatus {
    logger.info("Updating task \(taskId) status to \(status.rawValue) for user \(userId)")

    let completedAt: String? = status == .completed ? taskIsoFormatterFractional.string(from: Date()) : nil
    let payload = AthleteTaskUpsert(taskId: taskId, athleteId: userId, status: status.rawValue, completedAt: completedAt)

    let result: AthleteTaskStatus = try await supabaseManager.client
      .from("athlete_task")
      .upsert(payload, onConflict: "athlete_id,task_id")
      .select()
      .single()
      .execute()
      .value

    logger.info("Updated athlete_task for task \(taskId)")
    return result
  }
}
