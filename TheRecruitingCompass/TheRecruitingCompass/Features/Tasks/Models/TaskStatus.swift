import Foundation

enum TaskStatus: String, Codable, CaseIterable, Sendable {
  case notStarted = "not_started"
  case inProgress = "in_progress"
  case completed = "completed"

  var displayName: String {
    switch self {
    case .notStarted: return String(localized: "Not Started")
    case .inProgress: return String(localized: "In Progress")
    case .completed: return String(localized: "Completed")
    }
  }
}
