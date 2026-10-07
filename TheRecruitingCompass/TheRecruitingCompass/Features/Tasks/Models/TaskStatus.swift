import Foundation

enum TaskStatus: String, Codable, CaseIterable, Sendable {
  case notStarted = "not_started"
  case inProgress = "in_progress"
  case completed = "completed"
  case unknown

  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = TaskStatus(rawValue: rawValue) ?? .unknown
  }

  /// User-selectable values. Excludes `unknown`: a decode-only fallback for server values this build lacks.
  static var selectableCases: [TaskStatus] {
    allCases.filter { $0 != .unknown }
  }

  var displayName: String {
    switch self {
    case .notStarted: return String(localized: "Not Started")
    case .inProgress: return String(localized: "In Progress")
    case .completed: return String(localized: "Completed")
    case .unknown: return String(localized: "Unknown")
    }
  }
}
