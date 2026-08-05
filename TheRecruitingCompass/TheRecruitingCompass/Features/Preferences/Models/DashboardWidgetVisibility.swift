import Foundation

struct DashboardWidgetVisibility: Codable, Equatable {
  var statsCards: StatsCardVisibility
  var widgets: WidgetVisibility

  static var `default`: DashboardWidgetVisibility {
    DashboardWidgetVisibility(
      statsCards: .default,
      widgets: .default
    )
  }

  enum CodingKeys: String, CodingKey {
    case statsCards
    case widgets
  }
}
