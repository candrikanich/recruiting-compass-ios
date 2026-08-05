import Foundation

enum TimePeriod: Int, CaseIterable, Sendable {
  case last7Days = 7
  case last14Days = 14
  case last30Days = 30
  case last90Days = 90

  var displayName: String {
    switch self {
    case .last7Days: return "Last 7 days"
    case .last14Days: return "Last 14 days"
    case .last30Days: return "Last 30 days"
    case .last90Days: return "Last 90 days"
    }
  }
}
