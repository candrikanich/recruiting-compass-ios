import Foundation

/// Classifies how much horizontal space a widget occupies on the iPad 4+2 dashboard grid.
enum WidgetWidth {
  case full    // spans entire main column on iPad
  case half    // shares row with another .half widget on iPad
  case sidebar // pinned to right sidebar column on iPad, inline on iPhone
}

/// Stable identity for each user-arrangeable dashboard widget. Single source of truth for the
/// widget's label, icon, and its on/off flag on `WidgetVisibility` — reused by both the dashboard
/// renderer (`DashboardWidgetStack`) and the customize screen so order and visibility stay in sync.
enum DashboardWidgetID: String, CaseIterable, Codable, Identifiable {
  case actionItems
  case coachFollowup
  case upcomingEvents
  case quickTasks
  case atAGlance
  case recruitingCalendar
  case performance
  case interactionTrends
  case recentActivity

  var id: String { rawValue }

  /// The value-first default ordering (Phase 1). Also the fallback when no saved order exists.
  static var defaultOrder: [DashboardWidgetID] {
    [.actionItems, .coachFollowup, .upcomingEvents, .quickTasks, .atAGlance,
     .recruitingCalendar, .performance, .interactionTrends, .recentActivity]
  }

  /// Maps the widget to its existing on/off flag on `WidgetVisibility`.
  var visibilityKeyPath: WritableKeyPath<WidgetVisibility, Bool> {
    switch self {
    case .actionItems: return \.actionItems
    case .coachFollowup: return \.coachFollowupWidget
    case .upcomingEvents: return \.eventsSummary
    case .quickTasks: return \.quickTasks
    case .atAGlance: return \.atAGlanceSummary
    case .recruitingCalendar: return \.recruitingCalendar
    case .performance: return \.performanceSummary
    case .interactionTrends: return \.interactionTrendChart
    case .recentActivity: return \.recentActivity
    }
  }

  var label: String {
    switch self {
    case .actionItems: return String(localized: "Action Items")
    case .coachFollowup: return String(localized: "Coaches Follow-up")
    case .upcomingEvents: return String(localized: "Events Summary")
    case .quickTasks: return String(localized: "Quick Tasks")
    case .atAGlance: return String(localized: "At A Glance")
    case .recruitingCalendar: return String(localized: "Recruiting Calendar")
    case .performance: return String(localized: "Performance")
    case .interactionTrends: return String(localized: "Interaction Trend")
    case .recentActivity: return String(localized: "Recent Activity")
    }
  }

  /// Horizontal space this widget occupies on the iPad 4+2 dashboard grid.
  var widthClass: WidgetWidth {
    switch self {
    case .actionItems: return .full
    case .coachFollowup: return .half
    case .upcomingEvents: return .half
    case .quickTasks: return .half
    case .atAGlance: return .half
    case .recruitingCalendar: return .sidebar
    case .performance: return .half
    case .interactionTrends: return .full
    case .recentActivity: return .sidebar
    }
  }

  var icon: String {
    switch self {
    case .actionItems: return "sparkles"
    case .coachFollowup: return "person.wave.2.fill"
    case .upcomingEvents: return "calendar.badge.clock"
    case .quickTasks: return "checkmark.circle.fill"
    case .atAGlance: return "eye.fill"
    case .recruitingCalendar: return "calendar"
    case .performance: return "chart.bar.doc.horizontal"
    case .interactionTrends: return "chart.line.uptrend.xyaxis"
    case .recentActivity: return "clock.arrow.circlepath"
    }
  }

  /// Normalizes a stored order: keeps known ids in stored order, drops unknowns, then appends any
  /// known id missing from the stored list (in `defaultOrder` position). Guarantees every live
  /// widget appears exactly once regardless of what was persisted by an older/newer build.
  static func normalizedOrder(from stored: [String]) -> [DashboardWidgetID] {
    var seen = Set<DashboardWidgetID>()
    var result: [DashboardWidgetID] = []
    for raw in stored {
      guard let id = DashboardWidgetID(rawValue: raw), !seen.contains(id) else { continue }
      seen.insert(id)
      result.append(id)
    }
    for id in defaultOrder where !seen.contains(id) {
      result.append(id)
    }
    return result
  }
}
