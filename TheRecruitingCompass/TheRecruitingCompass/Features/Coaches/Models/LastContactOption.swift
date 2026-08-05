import Foundation

enum LastContactOption: Int, CaseIterable, Sendable {
  case sevenDays = 7
  case thirtyDays = 30
  case sixtyDays = 60
  case ninetyDays = 90

  var displayName: String {
    switch self {
    case .sevenDays: return "Last 7 days"
    case .thirtyDays: return "Last 30 days"
    case .sixtyDays: return "Last 60 days"
    case .ninetyDays: return "Last 90 days"
    }
  }
}
