import SwiftUI

struct NotificationBulkActions: View {
  let hasUnread: Bool
  let hasRead: Bool
  let onMarkAllRead: () -> Void
  let onClearRead: () -> Void

  var markAllReadAccessibilityLabel: String { String(localized: "Mark all as read") }
  var clearReadAccessibilityLabel: String { String(localized: "Clear read notifications") }

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onMarkAllRead) {
        Label(markAllReadAccessibilityLabel, systemImage: "checkmark.circle")
          .font(.subheadline.weight(.medium))
      }
      .disabled(!hasUnread)
      .accessibilityIdentifier("Mark all as read")
      .accessibilityLabel(markAllReadAccessibilityLabel)

      Spacer()

      Button(role: .destructive, action: onClearRead) {
        Label(clearReadAccessibilityLabel, systemImage: "trash")
          .font(.subheadline.weight(.medium))
      }
      .disabled(!hasRead)
      .accessibilityIdentifier("Clear read notifications")
      .accessibilityLabel(clearReadAccessibilityLabel)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .frame(minHeight: 44)
  }
}
