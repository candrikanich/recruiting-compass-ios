import SwiftUI

struct ActionItemsWidget: View {
  let suggestions: [Suggestion]
  let pendingCount: Int
  let canDismissOrComplete: Bool
  let onDismiss: (String) -> Void
  let onComplete: (String) -> Void

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
              canDismissOrComplete: canDismissOrComplete,
              onDismiss: { onDismiss(suggestion.id) },
              onComplete: { onComplete(suggestion.id) }
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
          .accessibilityLabel("View all action items")
          .accessibilityHint("Opens a complete list of suggested actions")
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .clipShape(.rect(cornerRadius: 12))
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct ActionItemCard: View {
  let suggestion: Suggestion
  let canDismissOrComplete: Bool
  let onDismiss: () -> Void
  let onComplete: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(suggestion.urgency.color)
        .frame(width: 8, height: 8)
        .padding(.top, 6)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(suggestion.urgency.rawValue.capitalized)
          .font(.caption)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(suggestion.urgency.color.opacity(0.15))
          .foregroundStyle(suggestion.urgency.color)
          .clipShape(.rect(cornerRadius: 4))
          .accessibilityHidden(true)

        Text(suggestion.message)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(Color.primary)
          .lineLimit(3)
      }

      Spacer()

      if canDismissOrComplete {
        VStack(spacing: 4) {
          Button(action: onComplete) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(Color.accentBlue)
              .font(.title3)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Complete suggestion")
          .accessibilityHint("Mark this suggestion as done")

          Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(Color.gray)
              .font(.title3)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Dismiss suggestion")
          .accessibilityHint("Hide this suggestion without completing it")
        }
      }
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
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
    canDismissOrComplete: true,
    onDismiss: { _ in },
    onComplete: { _ in }
  )
  .padding()
}
