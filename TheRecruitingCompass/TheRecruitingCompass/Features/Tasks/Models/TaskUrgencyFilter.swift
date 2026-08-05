import Foundation

/// Urgency filter for task list: All, Overdue/Due Soon, Due This Week, Due In 2 Weeks.
enum TaskUrgencyFilter: String, Codable, CaseIterable {
  case all
  case critical   // Overdue / Due Soon
  case urgent     // Due This Week
  case upcoming   // Due In 2 Weeks

  var displayName: String {
    switch self {
    case .all: return String(localized: "All")
    case .critical: return String(localized: "Overdue / Due Soon")
    case .urgent: return String(localized: "Due This Week")
    case .upcoming: return String(localized: "Due In 2 Weeks")
    }
  }

  func matches(_ urgency: TaskDeadlineUrgency) -> Bool {
    switch self {
    case .all: return true
    case .critical: return urgency == .critical
    case .urgent: return urgency == .urgent
    case .upcoming: return urgency == .upcoming
    }
  }
}
