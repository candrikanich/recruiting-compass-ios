import Foundation

enum DateRangeFilter: String, CaseIterable {
  case all = "All Dates"
  case upcoming = "Upcoming"
  case past = "Past"
  case thisMonth = "This Month"
  case nextMonth = "Next Month"

  var displayName: String {
    switch self {
    case .all: return String(localized: "All Dates")
    case .upcoming: return String(localized: "Upcoming")
    case .past: return String(localized: "Past")
    case .thisMonth: return String(localized: "This Month")
    case .nextMonth: return String(localized: "Next Month")
    }
  }
}
