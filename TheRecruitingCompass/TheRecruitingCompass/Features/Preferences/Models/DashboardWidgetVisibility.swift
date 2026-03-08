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

  init(coaches: Bool, schools: Bool, interactions: Bool, offers: Bool,
       events: Bool, performance: Bool, notifications: Bool, socialMedia: Bool) {
    self.coaches = coaches
    self.schools = schools
    self.interactions = interactions
    self.offers = offers
    self.events = events
    self.performance = performance
    self.notifications = notifications
    self.socialMedia = socialMedia
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    coaches = try c.decodeIfPresent(Bool.self, forKey: .coaches) ?? true
    schools = try c.decodeIfPresent(Bool.self, forKey: .schools) ?? true
    interactions = try c.decodeIfPresent(Bool.self, forKey: .interactions) ?? true
    offers = try c.decodeIfPresent(Bool.self, forKey: .offers) ?? true
    events = try c.decodeIfPresent(Bool.self, forKey: .events) ?? true
    performance = try c.decodeIfPresent(Bool.self, forKey: .performance) ?? true
    notifications = try c.decodeIfPresent(Bool.self, forKey: .notifications) ?? true
    socialMedia = try c.decodeIfPresent(Bool.self, forKey: .socialMedia) ?? true
  }
}

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
  var coachResponsiveness: Bool
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
      coachResponsiveness: true,
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
    case coachResponsiveness
    case upcomingDeadlines
  }

  init(actionItems: Bool, quickTasks: Bool, atAGlanceSummary: Bool,
       interactionTrendChart: Bool, eventsSummary: Bool, performanceSummary: Bool,
       recentActivity: Bool, recentNotifications: Bool, linkedAccounts: Bool,
       recruitingCalendar: Bool, offerStatusOverview: Bool, schoolInterestChart: Bool,
       schoolMapWidget: Bool, coachFollowupWidget: Bool, recentDocuments: Bool,
       interactionStats: Bool, schoolStatusOverview: Bool, coachResponsiveness: Bool,
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
    self.coachResponsiveness = coachResponsiveness
    self.upcomingDeadlines = upcomingDeadlines
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    actionItems = try c.decodeIfPresent(Bool.self, forKey: .actionItems) ?? true
    quickTasks = try c.decodeIfPresent(Bool.self, forKey: .quickTasks) ?? true
    atAGlanceSummary = try c.decodeIfPresent(Bool.self, forKey: .atAGlanceSummary) ?? true
    interactionTrendChart = try c.decodeIfPresent(Bool.self, forKey: .interactionTrendChart) ?? true
    eventsSummary = try c.decodeIfPresent(Bool.self, forKey: .eventsSummary) ?? true
    performanceSummary = try c.decodeIfPresent(Bool.self, forKey: .performanceSummary) ?? true
    recentActivity = try c.decodeIfPresent(Bool.self, forKey: .recentActivity) ?? true
    recentNotifications = try c.decodeIfPresent(Bool.self, forKey: .recentNotifications) ?? true
    linkedAccounts = try c.decodeIfPresent(Bool.self, forKey: .linkedAccounts) ?? true
    recruitingCalendar = try c.decodeIfPresent(Bool.self, forKey: .recruitingCalendar) ?? true
    offerStatusOverview = try c.decodeIfPresent(Bool.self, forKey: .offerStatusOverview) ?? true
    schoolInterestChart = try c.decodeIfPresent(Bool.self, forKey: .schoolInterestChart) ?? true
    schoolMapWidget = try c.decodeIfPresent(Bool.self, forKey: .schoolMapWidget) ?? true
    coachFollowupWidget = try c.decodeIfPresent(Bool.self, forKey: .coachFollowupWidget) ?? true
    recentDocuments = try c.decodeIfPresent(Bool.self, forKey: .recentDocuments) ?? true
    interactionStats = try c.decodeIfPresent(Bool.self, forKey: .interactionStats) ?? true
    schoolStatusOverview = try c.decodeIfPresent(Bool.self, forKey: .schoolStatusOverview) ?? true
    coachResponsiveness = try c.decodeIfPresent(Bool.self, forKey: .coachResponsiveness) ?? true
    upcomingDeadlines = try c.decodeIfPresent(Bool.self, forKey: .upcomingDeadlines) ?? true
  }
}
