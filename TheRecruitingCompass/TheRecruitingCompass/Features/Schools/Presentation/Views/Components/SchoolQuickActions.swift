import SwiftUI

struct SchoolQuickActions: View {
  let onLogInteraction: () -> Void
  let onQuickComm: () -> Void
  let onManageCoaches: () -> Void
  let coachCount: Int
  @Environment(FeatureFlagStore.self) private var featureFlags: FeatureFlagStore?

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
          style: .primary,
          action: onLogInteraction
        )

        if featureFlags.isEnabled(.athleteMessages) {
          QuickActionButton(
          icon: "envelope.badge.fill",
          title: String(localized: "Quick Comm"),
          style: .neutral,
          action: onQuickComm,
          isDisabled: coachCount == 0
          )
        }

        QuickActionButton(
          icon: "person.2.fill",
          title: String(localized: "Manage Coaches"),
          style: .neutral,
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
  /// "One accent, neutral everything else": the primary action is solid forest, the rest are bordered neutrals.
  enum Style {
    case primary, neutral

    var iconBackground: Color { self == .primary ? Color.accentFill : Color.Surface.card }
    var iconForeground: Color { self == .primary ? .white : Color.accentPrimary }
  }

  let icon: String
  let title: String
  let style: Style
  let action: () -> Void
  var isDisabled: Bool = false

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(sizeCategory.isAccessibilityCategory ? .title2 : .title3)
          .foregroundStyle(style.iconForeground)
          .frame(width: 48, height: 48)
          .background(style.iconBackground)
          .clipShape(Circle())
          .overlay(Circle().stroke(Color.Surface.borderStrong, lineWidth: style == .primary ? 0 : 1))
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
      .background(Color.Surface.muted)
      .clipShape(.rect(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.4 : 1.0)
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel(title)
    .accessibilityAddTraits(.isButton)
  }
}

#Preview {
  SchoolQuickActions(
    onLogInteraction: {},
    onQuickComm: {},
    onManageCoaches: {},
    coachCount: 2
  )
  .padding()
}
