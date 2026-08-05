import SwiftUI

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
        Text(suggestion.urgency.displayName)
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
          .accessibilityLabel(String(localized: "Complete suggestion"))
          .accessibilityHint("Mark this suggestion as done")

          Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(Color.gray)
              .font(.title3)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(String(localized: "Dismiss suggestion"))
          .accessibilityHint("Hide this suggestion without completing it")
        }
      }
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
  }
}
