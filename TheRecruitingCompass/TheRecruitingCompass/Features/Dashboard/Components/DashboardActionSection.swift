import SwiftUI

/// The "Act now" zone: what the athlete/parent should do today — suggested actions, coaches due
/// for follow-up, upcoming deadline events, and personal quick tasks. Extracted so SwiftUI can
/// skip re-evaluating this body when only insights/chart state changes.
struct DashboardActionSection: View {
  let visibility: WidgetVisibility
  let suggestions: [Suggestion]
  let pendingCount: Int
  let familyUnitId: String
  let userId: String
  let coachesNeedingFollowup: [Coach]
  let allSchools: [School]
  let events: [FullEvent]
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

  var body: some View {
    VStack(spacing: 16) {
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

      if visibility.coachFollowupWidget && !coachesNeedingFollowup.isEmpty {
        CoachFollowupWidget(coaches: coachesNeedingFollowup, schools: allSchools,
                            onCoachContacted: onCoachContacted)
      }

      if visibility.eventsSummary && !events.isEmpty {
        UpcomingEventsWidget(events: events)
      }

      if visibility.quickTasks {
        QuickTaskWidget(
          tasks: $quickTasks,
          onAddTask: onAddTask,
          onToggleTask: onToggleTask,
          onDeleteTask: onDeleteTask,
          onClearCompleted: onClearCompleted
        )
      }
    }
  }
}
