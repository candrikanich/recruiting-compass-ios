import Foundation

enum TaskStatus: String, Codable, CaseIterable, Sendable {
  case notStarted = "not_started"
  case inProgress = "in_progress"
  case completed = "completed"

  var displayName: String {
    switch self {
    case .notStarted: return "Not Started"
    case .inProgress: return "In Progress"
    case .completed: return "Completed"
    }
  }
}
