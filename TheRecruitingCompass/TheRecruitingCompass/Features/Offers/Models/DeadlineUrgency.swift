import SwiftUI

enum DeadlineUrgency: Sendable {
  case overdue
  case critical
  case urgent
  case normal
  case none

  var color: Color {
    switch self {
    case .overdue, .critical: return .errorRed
    case .urgent: return Color(hex: "F59E0B")
    case .normal, .none: return .secondary
    }
  }

  var label: String? {
    switch self {
    case .overdue: return "Overdue"
    case .critical: return "Deadline Soon"
    case .urgent: return "Upcoming"
    case .normal, .none: return nil
    }
  }
}
