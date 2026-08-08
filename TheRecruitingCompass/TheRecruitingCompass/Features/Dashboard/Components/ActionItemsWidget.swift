import SwiftUI

struct ActionItemsWidget: View {
  let suggestions: [Suggestion]
  let pendingCount: Int
  let familyUnitId: String
  let userId: String
  let onDismiss: (String) -> Void
  let onComplete: (String) -> Void
  let onActionCompleted: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Action Items")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Divider()

      if suggestions.isEmpty && pendingCount == 0 {
        Text("No action items at this time")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
          .padding(.vertical)
      } else {
        VStack(spacing: 12) {
          ForEach(suggestions.prefix(3)) { suggestion in
            ActionItemCard(
              suggestion: suggestion,
              familyUnitId: familyUnitId,
              userId: userId,
              onDismiss: { onDismiss(suggestion.id) },
              onComplete: { onComplete(suggestion.id) },
              onActionCompleted: onActionCompleted
            )
          }
        }

        let moreCount = max(0, suggestions.count - 3) + pendingCount
        if moreCount > 0 {
          NavigationLink(value: DashboardDestination.suggestions) {
            HStack(spacing: 4) {
              Text("Show \(moreCount) more")
                .font(.caption)
              Image(systemName: "chevron.right")
                .font(.caption)
                .accessibilityHidden(true)
            }
            .foregroundStyle(Color.accentBlue)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(String(localized: "View all action items"))
          .accessibilityHint("Opens a complete list of suggested actions")
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}

#Preview {
  ActionItemsWidget(
    suggestions: [
      Suggestion(
        id: "1",
        ruleType: "interaction-gap",
        message: "It's been 30 days since you contacted State U",
        urgency: .high,
        actionType: "log_interaction",
        relatedSchoolId: nil,
        dismissed: false,
        completed: false,
        pendingSurface: nil,
        surfacedAt: "2026-02-01T12:00:00Z"
      ),
      Suggestion(
        id: "2",
        ruleType: "school-list-building",
        message: "Add your recent test results to your profile",
        urgency: .medium,
        actionType: "update_video",
        relatedSchoolId: nil,
        dismissed: false,
        completed: false,
        pendingSurface: nil,
        surfacedAt: "2026-02-05T10:00:00Z"
      )
    ],
    pendingCount: 1,
    familyUnitId: "fam-1",
    userId: "user-1",
    onDismiss: { _ in },
    onComplete: { _ in },
    onActionCompleted: {}
  )
  .padding()
}
