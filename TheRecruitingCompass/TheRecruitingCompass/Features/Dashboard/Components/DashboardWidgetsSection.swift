import SwiftUI

/// Action items and quick tasks widgets. Extracted so SwiftUI can skip re-evaluating this body
/// when only other view model state (e.g. stats, charts) changes.
struct DashboardWidgetsSection: View {
  let visibility: WidgetVisibility
  let suggestions: [Suggestion]
  let pendingCount: Int
  let familyUnitId: String
  let userId: String
  @Binding var quickTasks: [QuickTask]
  let onDismissSuggestion: (String) -> Void
  let onCompleteSuggestion: (String) -> Void
  let onActionCompleted: () -> Void
  let onAddTask: (String) -> Void
  let onToggleTask: (String) -> Void
  let onDeleteTask: (String) -> Void
  let onClearCompleted: () -> Void

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
