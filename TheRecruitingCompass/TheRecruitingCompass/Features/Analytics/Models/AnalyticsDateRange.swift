import Foundation

enum AnalyticsDateRange: Equatable, Sendable {
  case last7Days
  case last30Days
  case last90Days
  case custom(start: Date, end: Date)

  var displayName: String {
    switch self {
    case .last7Days: return String(localized: "Last 7 Days")
    case .last30Days: return String(localized: "Last 30 Days")
    case .last90Days: return String(localized: "Last 90 Days")
    case .custom: return String(localized: "Custom Range")
    }
  }

  var startDate: Date {
    switch self {
    case .last7Days:
      return Calendar.current.date(byAdding: .day, value: -7, to: Date.now) ?? Date.now
    case .last30Days:
      return Calendar.current.date(byAdding: .day, value: -30, to: Date.now) ?? Date.now
    case .last90Days:
      return Calendar.current.date(byAdding: .day, value: -90, to: Date.now) ?? Date.now
    case .custom(let start, _):
      return start
    }
  }

  var endDate: Date {
    switch self {
    case .last7Days, .last30Days, .last90Days:
      return Date.now
    case .custom(_, let end):
      return end
    }
  }

  var queryStartDate: String {
    Self.dateFormatter.string(from: startDate)
  }

  var queryEndDate: String {
    Self.dateFormatter.string(from: endDate)
  }

  static let allPresets: [AnalyticsDateRange] = [.last7Days, .last30Days, .last90Days]

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}
