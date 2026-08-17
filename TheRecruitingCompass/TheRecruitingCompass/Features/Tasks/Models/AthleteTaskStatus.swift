import Foundation

struct AthleteTaskStatus: Codable, Sendable {
  let taskId: String
  let userId: String
  let status: TaskStatus
  let completedAt: Date?
  let isRecoveryTask: Bool

  enum CodingKeys: String, CodingKey {
    case taskId = "task_id"
    case userId = "athlete_id"
    case status
    case completedAt = "completed_at"
    case isRecoveryTask = "is_recovery_task"
  }

  init(taskId: String, userId: String, status: TaskStatus, completedAt: Date?, isRecoveryTask: Bool = false) {
    self.taskId = taskId
    self.userId = userId
    self.status = status
    self.completedAt = completedAt
    self.isRecoveryTask = isRecoveryTask
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    taskId = try c.decode(String.self, forKey: .taskId)
    userId = try c.decode(String.self, forKey: .userId)
    status = try c.decode(TaskStatus.self, forKey: .status)
    completedAt = try Self.decodeOptionalDate(c, forKey: .completedAt)
    isRecoveryTask = try c.decodeIfPresent(Bool.self, forKey: .isRecoveryTask) ?? false
  }

  private static let isoFormatterFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let isoFormatterBasic = ISO8601DateFormatter()

  private static func decodeOptionalDate(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
    guard let string = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
    return isoFormatterFractional.date(from: string) ?? isoFormatterBasic.date(from: string)
  }
}
