import SwiftUI

struct NotificationBulkActions: View {
  let hasUnread: Bool
  let hasRead: Bool
  let onMarkAllRead: () -> Void
  let onClearRead: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onMarkAllRead) {
        Label("Mark all as read", systemImage: "checkmark.circle")
          .font(.subheadline.weight(.medium))
      }
      .disabled(!hasUnread)
      .accessibilityLabel("Mark all as read")

      Spacer()

      Button(role: .destructive, action: onClearRead) {
        Label("Clear read notifications", systemImage: "trash")
          .font(.subheadline.weight(.medium))
      }
      .disabled(!hasRead)
      .accessibilityLabel("Clear read notifications")
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .frame(minHeight: 44)
  }
}
