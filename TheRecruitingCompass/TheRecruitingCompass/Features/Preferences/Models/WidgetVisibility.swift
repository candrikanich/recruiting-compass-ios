import Foundation

struct WidgetVisibility: Codable, Equatable {
  // Live widgets
  var actionItems: Bool
  var quickTasks: Bool
  var atAGlanceSummary: Bool
  var interactionTrendChart: Bool
  var eventsSummary: Bool
  var performanceSummary: Bool
  var recentActivity: Bool
  // Coming soon — stored for future use, not yet rendered
  var recentNotifications: Bool
  var linkedAccounts: Bool
  var recruitingCalendar: Bool
  var offerStatusOverview: Bool
  var schoolInterestChart: Bool
  var schoolMapWidget: Bool
  var coachFollowupWidget: Bool
  var recentDocuments: Bool
  var interactionStats: Bool
  var schoolStatusOverview: Bool
  var upcomingDeadlines: Bool

  static var `default`: WidgetVisibility {
    WidgetVisibility(
      actionItems: true,
      quickTasks: true,
      atAGlanceSummary: true,
      interactionTrendChart: true,
      eventsSummary: true,
      performanceSummary: true,
      recentActivity: true,
      recentNotifications: true,
      linkedAccounts: true,
      recruitingCalendar: true,
      offerStatusOverview: true,
      schoolInterestChart: true,
      schoolMapWidget: true,
      coachFollowupWidget: true,
      recentDocuments: true,
      interactionStats: true,
      schoolStatusOverview: true,
      upcomingDeadlines: true
    )
  }

  enum CodingKeys: String, CodingKey {
    case actionItems
    case quickTasks
    case atAGlanceSummary
    case interactionTrendChart
    case eventsSummary
    case performanceSummary
    case recentActivity
    case recentNotifications
    case linkedAccounts
    case recruitingCalendar
    case offerStatusOverview
    case schoolInterestChart
    case schoolMapWidget
    case coachFollowupWidget
    case recentDocuments
    case interactionStats
    case schoolStatusOverview
    case upcomingDeadlines
  }

  init(actionItems: Bool, quickTasks: Bool, atAGlanceSummary: Bool,
       interactionTrendChart: Bool, eventsSummary: Bool, performanceSummary: Bool,
       recentActivity: Bool, recentNotifications: Bool, linkedAccounts: Bool,
       recruitingCalendar: Bool, offerStatusOverview: Bool, schoolInterestChart: Bool,
       schoolMapWidget: Bool, coachFollowupWidget: Bool, recentDocuments: Bool,
       interactionStats: Bool, schoolStatusOverview: Bool,
       upcomingDeadlines: Bool) {
    self.actionItems = actionItems
    self.quickTasks = quickTasks
    self.atAGlanceSummary = atAGlanceSummary
    self.interactionTrendChart = interactionTrendChart
    self.eventsSummary = eventsSummary
    self.performanceSummary = performanceSummary
    self.recentActivity = recentActivity
    self.recentNotifications = recentNotifications
    self.linkedAccounts = linkedAccounts
    self.recruitingCalendar = recruitingCalendar
    self.offerStatusOverview = offerStatusOverview
    self.schoolInterestChart = schoolInterestChart
    self.schoolMapWidget = schoolMapWidget
    self.coachFollowupWidget = coachFollowupWidget
    self.recentDocuments = recentDocuments
    self.interactionStats = interactionStats
    self.schoolStatusOverview = schoolStatusOverview
    self.upcomingDeadlines = upcomingDeadlines
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    actionItems = try container.decodeIfPresent(Bool.self, forKey: .actionItems) ?? true
    quickTasks = try container.decodeIfPresent(Bool.self, forKey: .quickTasks) ?? true
    atAGlanceSummary = try container.decodeIfPresent(Bool.self, forKey: .atAGlanceSummary) ?? true
    interactionTrendChart = try container.decodeIfPresent(Bool.self, forKey: .interactionTrendChart) ?? true
    eventsSummary = try container.decodeIfPresent(Bool.self, forKey: .eventsSummary) ?? true
    performanceSummary = try container.decodeIfPresent(Bool.self, forKey: .performanceSummary) ?? true
    recentActivity = try container.decodeIfPresent(Bool.self, forKey: .recentActivity) ?? true
    recentNotifications = try container.decodeIfPresent(Bool.self, forKey: .recentNotifications) ?? true
    linkedAccounts = try container.decodeIfPresent(Bool.self, forKey: .linkedAccounts) ?? true
    recruitingCalendar = try container.decodeIfPresent(Bool.self, forKey: .recruitingCalendar) ?? true
    offerStatusOverview = try container.decodeIfPresent(Bool.self, forKey: .offerStatusOverview) ?? true
    schoolInterestChart = try container.decodeIfPresent(Bool.self, forKey: .schoolInterestChart) ?? true
    schoolMapWidget = try container.decodeIfPresent(Bool.self, forKey: .schoolMapWidget) ?? true
    coachFollowupWidget = try container.decodeIfPresent(Bool.self, forKey: .coachFollowupWidget) ?? true
    recentDocuments = try container.decodeIfPresent(Bool.self, forKey: .recentDocuments) ?? true
    interactionStats = try container.decodeIfPresent(Bool.self, forKey: .interactionStats) ?? true
    schoolStatusOverview = try container.decodeIfPresent(Bool.self, forKey: .schoolStatusOverview) ?? true
    upcomingDeadlines = try container.decodeIfPresent(Bool.self, forKey: .upcomingDeadlines) ?? true
  }
}
