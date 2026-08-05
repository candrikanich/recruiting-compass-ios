import Foundation
import SwiftUI

struct TaskWithStatus: Identifiable, Sendable {
  let id: String
  let title: String
  let description: String?
  let gradeLevel: Int
  let category: String
  let division: String?
  let required: Bool
  let deadlineDate: Date?
  let whyItMatters: String?
  let failureRisk: String?
  let dependencyTaskIds: [String]
  let athleteTask: AthleteTaskStatus?
  let prerequisiteTasks: [TaskSummary]
  let hasIncompletePrerequisites: Bool

  var isLocked: Bool { hasIncompletePrerequisites }

  var deadlineUrgency: TaskDeadlineUrgency {
    TaskDeadlineUrgency.from(deadline: deadlineDate)
  }

  /// Green = completed, yellow = in progress, gray = not started (per spec).
  var statusColor: Color {
    switch athleteTask?.status {
    case .completed: return .successGreen
    case .inProgress: return Color(hex: "F59E0B")
    case .notStarted, .none: return .secondary
    }
  }

  /// Shape cue paired with `statusColor` so status reads without color.
  var statusIconName: String {
    switch athleteTask?.status {
    case .completed: return "checkmark.circle.fill"
    case .inProgress: return "clock.fill"
    case .notStarted, .none: return "circle"
    }
  }

  /// Resolved status for display (defaults to notStarted when no athlete task).
  var effectiveStatus: TaskStatus {
    athleteTask?.status ?? .notStarted
  }

  init(
    id: String,
    title: String,
    description: String? = nil,
    gradeLevel: Int,
    category: String,
    division: String? = nil,
    required: Bool,
    deadlineDate: Date? = nil,
    whyItMatters: String? = nil,
    failureRisk: String? = nil,
    dependencyTaskIds: [String] = [],
    athleteTask: AthleteTaskStatus? = nil,
    prerequisiteTasks: [TaskSummary] = [],
    hasIncompletePrerequisites: Bool
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.gradeLevel = gradeLevel
    self.category = category
    self.division = division
    self.required = required
    self.deadlineDate = deadlineDate
    self.whyItMatters = whyItMatters
    self.failureRisk = failureRisk
    self.dependencyTaskIds = dependencyTaskIds
    self.athleteTask = athleteTask
    self.prerequisiteTasks = prerequisiteTasks
    self.hasIncompletePrerequisites = hasIncompletePrerequisites
  }
}

// MARK: - Codable (API decoding)

extension TaskWithStatus: Codable {
  enum CodingKeys: String, CodingKey {
    case id
    case title
    case description
    case gradeLevel = "grade_level"
    case category
    case division
    case required
    case deadlineDate = "deadline_date"
    case whyItMatters = "why_it_matters"
    case failureRisk = "failure_risk"
    case dependencyTaskIds = "dependency_task_ids"
    case athleteTask = "athlete_task"
    case prerequisiteTasks = "prerequisite_tasks"
    case hasIncompletePrerequisites = "has_incomplete_prerequisites"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    title = try c.decode(String.self, forKey: .title)
    description = try c.decodeIfPresent(String.self, forKey: .description)
    gradeLevel = try c.decode(Int.self, forKey: .gradeLevel)
    category = try c.decode(String.self, forKey: .category)
    division = try c.decodeIfPresent(String.self, forKey: .division)
    required = try c.decode(Bool.self, forKey: .required)
    deadlineDate = try Self.decodeOptionalDate(c, forKey: .deadlineDate)
    whyItMatters = try c.decodeIfPresent(String.self, forKey: .whyItMatters)
    failureRisk = try c.decodeIfPresent(String.self, forKey: .failureRisk)
    dependencyTaskIds = try c.decodeIfPresent([String].self, forKey: .dependencyTaskIds) ?? []
    athleteTask = try c.decodeIfPresent(AthleteTaskStatus.self, forKey: .athleteTask)
    prerequisiteTasks = try c.decodeIfPresent([TaskSummary].self, forKey: .prerequisiteTasks) ?? []
    hasIncompletePrerequisites = try c.decode(Bool.self, forKey: .hasIncompletePrerequisites)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(title, forKey: .title)
    try c.encodeIfPresent(description, forKey: .description)
    try c.encode(gradeLevel, forKey: .gradeLevel)
    try c.encode(category, forKey: .category)
    try c.encodeIfPresent(division, forKey: .division)
    try c.encode(required, forKey: .required)
    try Self.encodeOptionalDate(deadlineDate, to: &c, forKey: .deadlineDate)
    try c.encodeIfPresent(whyItMatters, forKey: .whyItMatters)
    try c.encodeIfPresent(failureRisk, forKey: .failureRisk)
    try c.encode(dependencyTaskIds, forKey: .dependencyTaskIds)
    try c.encodeIfPresent(athleteTask, forKey: .athleteTask)
    try c.encode(prerequisiteTasks, forKey: .prerequisiteTasks)
    try c.encode(hasIncompletePrerequisites, forKey: .hasIncompletePrerequisites)
  }

  private static func decodeOptionalDate(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
    if let string = try container.decodeIfPresent(String.self, forKey: key) {
      return Self.parseDate(string)
    }
    return nil
  }

  private static func encodeOptionalDate(_ date: Date?, to container: inout KeyedEncodingContainer<CodingKeys>, forKey key: CodingKeys) throws {
    if let date {
      try container.encode(iso8601String(from: date), forKey: key)
    } else {
      try container.encodeNil(forKey: key)
    }
  }

  private static let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let iso8601BasicFormatter = ISO8601DateFormatter()

  private static let dateOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private static func parseDate(_ string: String) -> Date? {
    iso8601Formatter.date(from: string)
      ?? iso8601BasicFormatter.date(from: string)
      ?? dateOnlyFormatter.date(from: string)
  }

  private static func iso8601String(from date: Date) -> String {
    iso8601Formatter.string(from: date)
  }
}
