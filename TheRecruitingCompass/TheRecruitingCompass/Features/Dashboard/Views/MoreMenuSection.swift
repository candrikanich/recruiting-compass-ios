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
    case .timeline: return String(localized: "Recruiting Timeline")
    case .events: return String(localized: "Events")
    case .documents: return String(localized: "Documents")
    case .offers: return String(localized: "Offers")
    case .performance: return String(localized: "Performance")
    case .analytics: return String(localized: "Analytics")
    case .activity: return String(localized: "Activity History")
    case .helpCenter: return String(localized: "Help Center")
    case .notifications: return String(localized: "Notifications")
    case .settings: return String(localized: "Settings")
    }
  }

  var description: String {
    switch self {
    case .timeline: return String(localized: "Phases, milestones, and recruiting roadmap")
    case .events: return String(localized: "Camps, visits, and key dates")
    case .documents: return String(localized: "Transcripts, videos, and files")
    case .offers: return String(localized: "Scholarship and offer tracking")
    case .performance: return String(localized: "Stats, metrics, and progress")
    case .analytics: return String(localized: "Charts and recruiting insights")
    case .activity: return String(localized: "History of your recruiting activity")
    case .helpCenter: return String(localized: "Guides and FAQs for using the app")
    case .notifications: return String(localized: "Alerts and follow-up reminders")
    case .settings: return String(localized: "Preferences and account settings")
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
