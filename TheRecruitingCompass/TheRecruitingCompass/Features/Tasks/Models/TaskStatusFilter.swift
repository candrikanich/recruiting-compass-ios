import Foundation

/// Status filter for task list: All, Not Started, In Progress, Completed.
enum TaskStatusFilter: String, Codable, CaseIterable {
  case all
  case notStarted
  case inProgress
  case completed

  var displayName: String {
    switch self {
    case .all: return String(localized: "All")
    case .notStarted: return String(localized: "Not Started")
    case .inProgress: return String(localized: "In Progress")
    case .completed: return String(localized: "Completed")
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
