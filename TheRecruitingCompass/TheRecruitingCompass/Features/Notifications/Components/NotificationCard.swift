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
              .foregroundStyle(notification.isRead ? .primary : Color(hex: "#1E40AF"))
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            PriorityBadge(priority: notification.priority)
          }

          Text(notification.message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)

          Text(formatRelativeDate(notification.scheduledFor))
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button(action: onDelete) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Delete notification")
      }
      .padding()
      .background(notification.isRead ? Color.Surface.card : Color(hex: "#EFF6FF"))
      .overlay(
        Rectangle()
          .fill(notification.isRead ? Color(hex: "#9CA3AF") : Color(hex: "#3B82F6"))
          .frame(width: 4),
        alignment: .leading
      )
      .clipShape(.rect(cornerRadius: 8))
      .brandShadowSm()
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("notification-card-\(notification.id)")
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint("Tap to view details")
    .accessibilityAddTraits(.isButton)
  }

  var accessibilityLabel: String {
    let status = notification.isRead ? "Read" : "Unread"
    let priority = notification.priority == .high ? "High priority" : ""
    let type = notification.type.label
    let time = formatRelativeDate(notification.scheduledFor)

    return [status, priority, type, notification.title, notification.message, time]
      .filter { !$0.isEmpty }
      .joined(separator: ". ")
  }

  private static let isoParser: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let isoParserFallback: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private static let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
  }()

  private func formatRelativeDate(_ dateString: String) -> String {
    guard let date = NotificationCard.isoParser.date(from: dateString)
      ?? NotificationCard.isoParserFallback.date(from: dateString) else {
      return dateString
    }

    let seconds = Date.now.timeIntervalSince(date)

    if seconds < 60 { return "just now" }
    if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
    if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
    if seconds < 604800 { return "\(Int(seconds / 86400))d ago" }

    return NotificationCard.shortDateFormatter.string(from: date)
  }
}
