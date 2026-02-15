import SwiftUI

struct NotificationCard: View {
  let notification: AppNotification
  let onTap: () -> Void
  let onMarkRead: () -> Void
  let onDelete: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        Text(notification.type.emoji)
          .font(.title3)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(notification.title)
              .font(notification.isRead ? .body : .body.weight(.semibold))
              .foregroundColor(notification.isRead ? .primary : Color(hex: "#1E40AF"))
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            PriorityBadge(priority: notification.priority)
          }

          Text(notification.message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)

          Text(formatRelativeDate(notification.scheduledFor))
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        Button(action: onDelete) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Delete notification")
      }
      .padding()
      .background(notification.isRead ? Color(.systemBackground) : Color(hex: "#EFF6FF"))
      .overlay(
        Rectangle()
          .fill(notification.isRead ? Color(hex: "#9CA3AF") : Color(hex: "#3B82F6"))
          .frame(width: 4),
        alignment: .leading
      )
      .cornerRadius(8)
      .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("notification-card-\(notification.id)")
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Tap to view details")
    .accessibilityAddTraits(.isButton)
  }

  private var accessibilityLabel: String {
    let status = notification.isRead ? "Read" : "Unread"
    let priority = notification.priority == .high ? "High priority" : ""
    let type = notification.type.label
    let time = formatRelativeDate(notification.scheduledFor)

    return [status, priority, type, notification.title, notification.message, time]
      .filter { !$0.isEmpty }
      .joined(separator: ". ")
  }

  private func formatRelativeDate(_ dateString: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: dateString) else {
      return dateString
    }

    let seconds = Date().timeIntervalSince(date)

    if seconds < 60 { return "just now" }
    if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
    if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
    if seconds < 604800 { return "\(Int(seconds / 86400))d ago" }

    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
  }
}

struct PriorityBadge: View {
  let priority: NotificationPriority

  private var textColor: Color {
    switch priority {
    case .high: return Color(hex: "#B91C1C")
    case .normal: return Color(hex: "#1D4ED8")
    case .low: return Color(hex: "#4B5563")
    }
  }

  private var backgroundColor: Color {
    switch priority {
    case .high: return Color(hex: "#FEE2E2")
    case .normal: return Color(hex: "#DBEAFE")
    case .low: return Color(hex: "#F3F4F6")
    }
  }

  var body: some View {
    Text(priority.rawValue.uppercased())
      .font(.caption2.weight(.bold))
      .foregroundColor(textColor)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(backgroundColor)
      .cornerRadius(4)
  }
}
