import SwiftUI

enum MoreMenuSection: String, CaseIterable, Identifiable {
  case timeline
  case events
  case documents
  case offers
  case performance
  case analytics
  case activity
  case helpCenter
  case notifications
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .timeline: return "Recruiting Timeline"
    case .events: return "Events"
    case .documents: return "Documents"
    case .offers: return "Offers"
    case .performance: return "Performance"
    case .analytics: return "Analytics"
    case .activity: return "Activity History"
    case .helpCenter: return "Help Center"
    case .notifications: return "Notifications"
    case .settings: return "Settings"
    }
  }

  var description: String {
    switch self {
    case .timeline: return "Phases, milestones, and recruiting roadmap"
    case .events: return "Camps, visits, and key dates"
    case .documents: return "Transcripts, videos, and files"
    case .offers: return "Scholarship and offer tracking"
    case .performance: return "Stats, metrics, and progress"
    case .analytics: return "Charts and recruiting insights"
    case .activity: return "History of your recruiting activity"
    case .helpCenter: return "Guides and FAQs for using the app"
    case .notifications: return "Alerts and follow-up reminders"
    case .settings: return "Preferences and account settings"
    }
  }

  var icon: String {
    switch self {
    case .timeline: return "clock"
    case .events: return "calendar"
    case .documents: return "doc"
    case .offers: return "gift"
    case .performance: return "chart.xyaxis.line"
    case .analytics: return "chart.pie"
    case .activity: return "list.bullet.rectangle"
    case .helpCenter: return "questionmark.circle"
    case .notifications: return "bell"
    case .settings: return "gearshape"
    }
  }

  var color: Color {
    switch self {
    case .timeline: return .blue
    case .events: return .purple
    case .documents: return .blue
    case .offers: return .green
    case .performance: return .orange
    case .analytics: return .purple
    case .activity: return .accentBlue
    case .helpCenter: return .accentBlue
    case .notifications: return .orange
    case .settings: return Color.iconGray
    }
  }

  /// Sections grouped for list display (header title → items).
  static var recruitingSections: [(header: String, items: [MoreMenuSection])] {
    [
      ("Recruiting", [.timeline, .events, .documents, .offers, .performance, .analytics, .activity]),
      ("Support", [.helpCenter]),
      ("Account", [.notifications, .settings])
    ]
  }
}
