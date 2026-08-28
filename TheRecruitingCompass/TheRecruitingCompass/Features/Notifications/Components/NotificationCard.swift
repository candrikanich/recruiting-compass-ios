import SwiftUI

struct NotificationCard: View, Equatable {
  let notification: AppNotification
  let onTap: () -> Void
  let onMarkRead: () -> Void
  let onDelete: () -> Void

  static func == (lhs: NotificationCard, rhs: NotificationCard) -> Bool {
    lhs.notification == rhs.notification
  }

  private enum Palette {
    static let unreadTitle = Color(hex: "#1E40AF")
    static let unreadBackground = Color(hex: "#EFF6FF")
    static let unreadBar = Color(hex: "#3B82F6")
    static let readBar = Color(hex: "#9CA3AF")
  }

  var body: some View {
    let relative = Self.formatRelativeDate(notification.scheduledFor)

    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        Text(notification.type.emoji)
          .font(.title3)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(notification.title)
              .font(notification.isRead ? .body : .body.weight(.semibold))
              .foregroundStyle(notification.isRead ? .primary : Palette.unreadTitle)
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            PriorityBadge(priority: notification.priority)
          }

          Text(notification.message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)

          Text(relative)
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
        .accessibilityLabel(String(localized: "Delete notification"))
      }
      .padding()
      .background(notification.isRead ? Color.Surface.card : Palette.unreadBackground)
      .overlay(
        Rectangle()
          .fill(notification.isRead ? Palette.readBar : Palette.unreadBar)
          .frame(width: 4),
        alignment: .leading
      )
      .clipShape(.rect(cornerRadius: 8))
      .brandShadowSm()
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("notification-card-\(notification.id)")
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(relativeDate: relative))
    .accessibilityHint("Tap to view details")
    .accessibilityAddTraits(.isButton)
  }

  /// Used by unit tests; body passes the already-formatted relative string.
  var accessibilityLabel: String {
    accessibilityLabel(relativeDate: Self.formatRelativeDate(notification.scheduledFor))
  }

  private func accessibilityLabel(relativeDate: String) -> String {
    let status = notification.isRead ? "Read" : "Unread"
    let priority = notification.priority == .high ? "High priority" : ""
    let type = notification.type.label

    let joined = [status, priority, type, notification.title, notification.message, relativeDate]
      .filter { !$0.isEmpty }
      .joined(separator: ". ")
    return String(localized: "\(joined)")
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

  static func formatRelativeDate(_ dateString: String) -> String {
    guard let date = isoParser.date(from: dateString)
      ?? isoParserFallback.date(from: dateString) else {
      return dateString
    }

    let seconds = Date.now.timeIntervalSince(date)

    if seconds < 60 { return String(localized: "just now") }
    if seconds < 3600 { return String(localized: "\(Int(seconds / 60))m ago") }
    if seconds < 86400 { return String(localized: "\(Int(seconds / 3600))h ago") }
    if seconds < 604800 { return String(localized: "\(Int(seconds / 86400))d ago") }

    return shortDateFormatter.string(from: date)
  }
}
