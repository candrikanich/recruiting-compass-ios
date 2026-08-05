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
    case .urgent: return .amberGold
    case .normal, .none: return .secondary
    }
  }

  var label: String? {
    switch self {
    case .overdue: return String(localized: "Overdue")
    case .critical: return String(localized: "Deadline Soon")
    case .urgent: return String(localized: "Upcoming")
    case .normal, .none: return nil
    }
  }
}
