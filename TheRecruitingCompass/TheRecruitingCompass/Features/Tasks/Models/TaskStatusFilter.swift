import Foundation

/// Status filter for task list: All, Not Started, In Progress, Completed.
enum TaskStatusFilter: String, Codable, CaseIterable {
  case all
  case notStarted
  case inProgress
  case completed

  var displayName: String {
    switch self {
    case .all: return "All"
    case .notStarted: return "Not Started"
    case .inProgress: return "In Progress"
    case .completed: return "Completed"
    }
  }

  func matches(_ status: TaskStatus) -> Bool {
    switch self {
    case .all: return true
    case .notStarted: return status == .notStarted
    case .inProgress: return status == .inProgress
    case .completed: return status == .completed
    }
  }
}
