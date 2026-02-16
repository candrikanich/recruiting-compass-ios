import SwiftUI

struct NotificationEmptyState: View {
  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "bell.badge.slash")
        .font(.system(size: iconSize))
        .foregroundColor(.secondary)
        .accessibilityHidden(true)

      Text("No notifications")
        .font(.title3.weight(.semibold))

      Text("You're all caught up!")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("No notifications")
    .accessibilityLabel("No notifications. You're all caught up!")
  }
}
