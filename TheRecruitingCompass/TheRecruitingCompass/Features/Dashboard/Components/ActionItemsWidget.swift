import SwiftUI

struct ActionItemsWidget: View {
  let suggestions: [Suggestion]
  let onDismiss: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Action Items")
        .font(.headline)

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
              onDismiss: { onDismiss(suggestion.id) }
            )
          }
        }

        if suggestions.count > 3 {
          Button("Show \(suggestions.count - 3) more") {
          }
          .font(.caption)
          .foregroundColor(Color.accentBlue)
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

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(suggestion.urgency.color)
        .frame(width: 8, height: 8)
        .padding(.top, 6)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(suggestion.title)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(suggestion.description)
          .font(.caption)
          .foregroundColor(Color.secondaryText)
          .lineLimit(2)
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(Color.gray)
      }
      .buttonStyle(PlainButtonStyle())
      .accessibilityLabel("Dismiss suggestion")
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(suggestion.urgency.rawValue) priority: \(suggestion.title). \(suggestion.description)")
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
    onDismiss: { _ in }
  )
  .padding()
}
