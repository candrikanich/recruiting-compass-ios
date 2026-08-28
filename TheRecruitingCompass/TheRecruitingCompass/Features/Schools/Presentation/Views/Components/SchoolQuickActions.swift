import SwiftUI

struct SchoolQuickActions: View {
  let onLogInteraction: () -> Void
  let onSendEmail: () -> Void
  let onManageCoaches: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Quick Actions", systemImage: "bolt")
        .font(.headline)
        .foregroundStyle(.primary)
        .accessibilityAddTraits(.isHeader)

      HStack(spacing: 12) {
        QuickActionButton(
          icon: "plus.message.fill",
          title: String(localized: "Log Interaction"),
          gradient: LinearGradient(
            colors: [Color.accentBlue, Color.accentBlue.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          action: onLogInteraction
        )

        QuickActionButton(
          icon: "envelope.fill",
          title: String(localized: "Send Email"),
          gradient: LinearGradient(
            colors: [Color.successGreen, Color.successGreen.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          action: onSendEmail
        )

        QuickActionButton(
          icon: "person.2.fill",
          title: String(localized: "Manage Coaches"),
          gradient: LinearGradient(
            colors: [Color.purple, Color.purple.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          action: onManageCoaches
        )
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowMd()
  }
}

private struct QuickActionButton: View {
  let icon: String
  let title: String
  let gradient: LinearGradient
  let action: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(sizeCategory.isAccessibilityCategory ? .title2 : .title3)
          .foregroundStyle(.white)
          .frame(width: 48, height: 48)
          .background(gradient)
          .clipShape(Circle())
          .accessibilityHidden(true)

        Text(title)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(Color(.systemGray6))
      .clipShape(.rect(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel(title)
    .accessibilityAddTraits(.isButton)
  }
}

#Preview {
  SchoolQuickActions(
    onLogInteraction: {},
    onSendEmail: {},
    onManageCoaches: {}
  )
  .padding()
}
