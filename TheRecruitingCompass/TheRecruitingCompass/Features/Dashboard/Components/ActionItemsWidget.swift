import SwiftUI

struct ActionItemsWidget: View {
  let suggestions: [Suggestion]
  let onDismiss: (String) -> Void
  let onComplete: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Action Items")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Divider()

      if suggestions.isEmpty {
        Text("No action items at this time")
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .padding(.vertical)
      } else {
        VStack(spacing: 12) {
          ForEach(suggestions.prefix(3)) { suggestion in
            ActionItemCard(
              suggestion: suggestion,
              onDismiss: { onDismiss(suggestion.id) },
              onComplete: { onComplete(suggestion.id) }
            )
          }
        }

        if suggestions.count > 3 {
          NavigationLink(value: DashboardDestination.suggestions) {
            HStack(spacing: 4) {
              Text("Show \(suggestions.count - 3) more")
                .font(.caption)
              Image(systemName: "chevron.right")
                .font(.caption2)
                .accessibilityHidden(true)
            }
            .foregroundColor(Color.accentBlue)
          }
          .buttonStyle(PlainButtonStyle())
          .accessibilityLabel("View all action items")
          .accessibilityHint("Opens a complete list of \(suggestions.count) suggested actions")
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct ActionItemCard: View {
  let suggestion: Suggestion
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
        HStack(spacing: 6) {
          Text(suggestion.title)
            .font(.subheadline)
            .fontWeight(.semibold)

          Text(suggestion.urgency.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(suggestion.urgency.color.opacity(0.15))
            .foregroundColor(suggestion.urgency.color)
            .cornerRadius(4)
            .accessibilityHidden(true)
        }

        Text(suggestion.description)
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .lineLimit(2)
      }

      Spacer()

      VStack(spacing: 4) {
        Button(action: onComplete) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(Color.accentBlue)
            .font(.title3)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Complete: \(suggestion.title)")
        .accessibilityHint("Mark this suggestion as done")

        Button(action: onDismiss) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(Color.gray)
            .font(.title3)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Dismiss: \(suggestion.title)")
        .accessibilityHint("Hide this suggestion without completing it")
      }
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
  }
}

#Preview {
  ActionItemsWidget(
    suggestions: [
      Suggestion(
        id: "1",
        title: "Follow up with Coach Johnson",
        description: "It's been 2 weeks since your last contact",
        urgency: .high,
        actionUrl: nil,
        location: "dashboard",
        createdAt: "2026-02-01T12:00:00Z"
      ),
      Suggestion(
        id: "2",
        title: "Update your SAT score",
        description: "Add your recent test results",
        urgency: .medium,
        actionUrl: nil,
        location: "dashboard",
        createdAt: "2026-02-05T10:00:00Z"
      )
    ],
    onDismiss: { _ in },
    onComplete: { _ in }
  )
  .padding()
}
