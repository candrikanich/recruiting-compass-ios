import SwiftUI

/// One row in the Deadlines list — category icon, label, date, days-until
/// badge, and a source badge for system (NCAA calendar) items.
struct DeadlineRow: View {
  let deadline: UnifiedDeadline
  /// Injectable "now" for testability — mirrors `RecruitingCalendarWidget`.
  var now: Date = .now

  private static let isoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private static let displayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private var formattedDate: String {
    guard let date = Self.isoFormatter.date(from: deadline.date) else { return deadline.date }
    return Self.displayFormatter.string(from: date)
  }

  /// Days between today (start-of-day, local) and the deadline date.
  /// Positive = future, 0 = today, negative = past.
  private var daysUntil: Int? {
    guard let target = Self.isoFormatter.date(from: deadline.date) else { return nil }
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    // isoFormatter parses in UTC; renormalize to a local start-of-day so a
    // day-of-year diff isn't thrown off by the parse timezone.
    var components = calendar.dateComponents([.year, .month, .day], from: target)
    components.timeZone = calendar.timeZone
    guard let localTarget = calendar.date(from: components) else { return nil }
    return calendar.dateComponents([.day], from: today, to: localTarget).day
  }

  private var daysUntilLabel: String {
    guard let daysUntil else { return "" }
    switch daysUntil {
    case ..<0: return String(localized: "Past")
    case 0: return String(localized: "Today")
    case 1: return String(localized: "Tomorrow")
    default: return String(localized: "\(daysUntil) days")
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: deadline.icon)
        .font(.body)
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(deadline.color)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(deadline.label)
          .font(.body.weight(.medium))
        HStack(spacing: 6) {
          Text(formattedDate)
          Text("\u{2022}")
          Text(deadline.categoryDisplayName)
          if deadline.source == .system {
            Text("\u{2022}")
            Text(deadline.sourceBadge)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      Text(daysUntilLabel)
        .font(.caption.weight(.semibold))
        .foregroundStyle(daysUntil.map { $0 < 0 ? Color.secondary : deadline.color } ?? .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((daysUntil.map { $0 < 0 ? Color.gray : deadline.color } ?? .gray).opacity(0.15))
        .clipShape(Capsule())
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      String(localized: "\(deadline.label), \(deadline.categoryDisplayName), \(daysUntilLabel)")
    )
  }
}
