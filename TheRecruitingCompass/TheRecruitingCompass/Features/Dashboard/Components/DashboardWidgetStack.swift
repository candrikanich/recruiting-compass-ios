import SwiftUI

/// Renders the live dashboard widgets in the user's chosen `order`, each gated by its visibility
/// flag plus its existing data-empty rule. Replaces the former Action/Insights section split so a
/// single flat, user-reorderable list can express any arrangement.
struct DashboardWidgetStack: View {
  let order: [DashboardWidgetID]
  let visibility: WidgetVisibility
  let suggestions: [Suggestion]
  let pendingCount: Int
  let familyUnitId: String
  let userId: String
  let coachesNeedingFollowup: [Coach]
  let allSchools: [School]
  let events: [FullEvent]
  let interactionTrends: [InteractionTrend]
  let metrics: [PerformanceMetric]
  let schoolsWithOffersPercentage: String
  let interactionsThisMonth: Int
  let daysUntilGraduationFormatted: String
  let isEmpty: Bool
  let athleteSport: String?
  let athleteGender: String?
  let graduationYear: Int?
  @Binding var quickTasks: [QuickTask]
  let onDismissSuggestion: (String) -> Void
  let onCompleteSuggestion: (String) -> Void
  let onActionCompleted: () -> Void
  let onAddTask: (String) -> Void
  let onToggleTask: (String) -> Void
  let onDeleteTask: (String) -> Void
  let onClearCompleted: () -> Void
  /// Reload the dashboard after a coach send (follow-up list refresh).
  var onCoachContacted: (() -> Void)?
  /// When set, widgets whose `widthClass` is in this set are skipped (iPad main-column pass).
  var excludeWidthClasses: Set<WidgetWidth>?
  /// When set, only widgets whose `widthClass` is in this set are rendered (iPad sidebar pass).
  var onlyWidthClasses: Set<WidgetWidth>?

  var body: some View {
    VStack(spacing: 16) {
      ForEach(order.filter(passesWidthFilter)) { id in
        widget(for: id)
      }
    }
  }

  private func passesWidthFilter(_ id: DashboardWidgetID) -> Bool {
    if let excludeWidthClasses, excludeWidthClasses.contains(id.widthClass) { return false }
    if let onlyWidthClasses, !onlyWidthClasses.contains(id.widthClass) { return false }
    return true
  }

  @ViewBuilder
  private func widget(for id: DashboardWidgetID) -> some View {
    switch id {
    case .actionItems:
      if visibility.actionItems {
        ActionItemsWidget(
          suggestions: suggestions,
          pendingCount: pendingCount,
          familyUnitId: familyUnitId,
          userId: userId,
          onDismiss: onDismissSuggestion,
          onComplete: onCompleteSuggestion,
          onActionCompleted: onActionCompleted
        )
      }

    case .coachFollowup:
      if visibility.coachFollowupWidget && !coachesNeedingFollowup.isEmpty {
        CoachFollowupWidget(coaches: coachesNeedingFollowup, schools: allSchools,
                            onCoachContacted: onCoachContacted)
      }

    case .upcomingEvents:
      if visibility.eventsSummary && !events.isEmpty {
        UpcomingEventsWidget(events: events)
      }

    case .quickTasks:
      if visibility.quickTasks {
        QuickTaskWidget(
          tasks: $quickTasks,
          onAddTask: onAddTask,
          onToggleTask: onToggleTask,
          onDeleteTask: onDeleteTask,
          onClearCompleted: onClearCompleted
        )
      }

    case .atAGlance:
      if visibility.atAGlanceSummary && !isEmpty {
        AtAGlanceSummary(
          schoolsWithOffers: schoolsWithOffersPercentage,
          interactionsThisMonth: interactionsThisMonth,
          daysUntilGraduation: daysUntilGraduationFormatted
        )
      }

    case .recruitingCalendar:
      if visibility.recruitingCalendar {
        RecruitingCalendarWidget(sport: athleteSport, gender: athleteGender, graduationYear: graduationYear)
      }

    case .performance:
      if visibility.performanceSummary && !metrics.isEmpty {
        PerformanceMetricsWidget(metrics: metrics)
      }

    case .interactionTrends:
      if visibility.interactionTrendChart && !interactionTrends.isEmpty {
        InteractionTrendsChart(trends: interactionTrends)
      }

    case .recentActivity:
      if visibility.recentActivity {
        RecentActivityWidget()
      }
    }
  }
}
