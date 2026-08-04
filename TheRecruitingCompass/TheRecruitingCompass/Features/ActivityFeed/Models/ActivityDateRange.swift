import Foundation

enum ActivityDateRange: String, CaseIterable, Sendable {
  case all
  case week
  case month
  case quarter

  var label: String {
    switch self {
    case .all: return "All Time"
    case .week: return "Last 7 Days"
    case .month: return "Last 30 Days"
    case .quarter: return "Last 90 Days"
    }
  }

  var daysAgo: Int? {
    switch self {
    case .all: return nil
    case .week: return 7
    case .month: return 30
    case .quarter: return 90
    }
  }
}
