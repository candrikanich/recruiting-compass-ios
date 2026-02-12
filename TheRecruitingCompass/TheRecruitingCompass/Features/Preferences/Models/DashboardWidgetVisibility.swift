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

struct StatsCardVisibility: Codable, Equatable {
  var coaches: Bool
  var schools: Bool
  var interactions: Bool
  var offers: Bool
  var events: Bool
  var performance: Bool
  var notifications: Bool
  var socialMedia: Bool

  static var `default`: StatsCardVisibility {
    StatsCardVisibility(
      coaches: true,
      schools: true,
      interactions: true,
      offers: true,
      events: true,
      performance: true,
      notifications: true,
      socialMedia: true
    )
  }

  enum CodingKeys: String, CodingKey {
    case coaches
    case schools
    case interactions
    case offers
    case events
    case performance
    case notifications
    case socialMedia
  }
}

struct WidgetVisibility: Codable, Equatable {
  var recentNotifications: Bool
  var linkedAccounts: Bool
  var recruitingCalendar: Bool
  var quickTasks: Bool
  var atAGlanceSummary: Bool
  var offerStatusOverview: Bool
  var interactionTrendChart: Bool
  var schoolInterestChart: Bool
  var schoolMapWidget: Bool
  var coachFollowupWidget: Bool
  var eventsSummary: Bool
  var performanceSummary: Bool
  var recentDocuments: Bool
  var interactionStats: Bool
  var schoolStatusOverview: Bool
  var coachResponsiveness: Bool
  var upcomingDeadlines: Bool

  static var `default`: WidgetVisibility {
    WidgetVisibility(
      recentNotifications: true,
      linkedAccounts: true,
      recruitingCalendar: true,
      quickTasks: true,
      atAGlanceSummary: true,
      offerStatusOverview: true,
      interactionTrendChart: true,
      schoolInterestChart: true,
      schoolMapWidget: true,
      coachFollowupWidget: true,
      eventsSummary: true,
      performanceSummary: true,
      recentDocuments: true,
      interactionStats: true,
      schoolStatusOverview: true,
      coachResponsiveness: true,
      upcomingDeadlines: true
    )
  }

  enum CodingKeys: String, CodingKey {
    case recentNotifications
    case linkedAccounts
    case recruitingCalendar
    case quickTasks
    case atAGlanceSummary
    case offerStatusOverview
    case interactionTrendChart
    case schoolInterestChart
    case schoolMapWidget
    case coachFollowupWidget
    case eventsSummary
    case performanceSummary
    case recentDocuments
    case interactionStats
    case schoolStatusOverview
    case coachResponsiveness
    case upcomingDeadlines
  }
}
