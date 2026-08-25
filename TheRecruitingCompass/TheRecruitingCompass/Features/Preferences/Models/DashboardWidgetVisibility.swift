import Foundation

struct DashboardWidgetVisibility: Codable, Equatable {
  var statsCards: StatsCardVisibility
  var widgets: WidgetVisibility
  /// User-arranged order of the live dashboard widgets. Normalized on decode so it always
  /// contains every `DashboardWidgetID` exactly once.
  var widgetOrder: [DashboardWidgetID]

  static var `default`: DashboardWidgetVisibility {
    DashboardWidgetVisibility(
      statsCards: .default,
      widgets: .default,
      widgetOrder: DashboardWidgetID.defaultOrder
    )
  }

  init(statsCards: StatsCardVisibility, widgets: WidgetVisibility,
       widgetOrder: [DashboardWidgetID] = DashboardWidgetID.defaultOrder) {
    self.statsCards = statsCards
    self.widgets = widgets
    self.widgetOrder = widgetOrder
  }

  enum CodingKeys: String, CodingKey {
    case statsCards
    case widgets
    case widgetOrder
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    statsCards = try container.decode(StatsCardVisibility.self, forKey: .statsCards)
    widgets = try container.decode(WidgetVisibility.self, forKey: .widgets)
    let storedOrder = try container.decodeIfPresent([String].self, forKey: .widgetOrder) ?? []
    widgetOrder = DashboardWidgetID.normalizedOrder(from: storedOrder)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(statsCards, forKey: .statsCards)
    try container.encode(widgets, forKey: .widgets)
    try container.encode(widgetOrder.map(\.rawValue), forKey: .widgetOrder)
  }
}
