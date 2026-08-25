import Foundation

/// Derived coach metrics — a pure port of the web `useCoachInsights` composable
/// so both platforms show identical numbers. `OVERDUE_DAYS = 14`.
struct CoachInsights: Sendable {
  let daysSinceContact: Int?
  let isOverdue: Bool
  let totalInteractions: Int
  let sent: Int
  let received: Int
  let responseRate: Int
  let preferredChannel: InteractionType?

  var overdueAlert: Bool { isOverdue }
  var channelPreferenceAlert: Bool { preferredChannel != nil && totalInteractions >= 1 }

  static let overdueDays = 14

  static func make(coach: Coach?, interactions: [Interaction], now: Date = .now) -> CoachInsights {
    let calendar = Calendar.current

    // Prefer the newest logged interaction; filter nil-occurredAt first so
    // Interaction.displayDate's `.now` default can't masquerade as "today".
    let latest = interactions.filter { $0.occurredAt != nil }.map(\.displayDate).max()
    let days: Int? = {
      if let latest { return calendar.dateComponents([.day], from: latest, to: now).day }
      guard let stored = coach?.lastContactDateParsed else { return nil }
      return calendar.dateComponents([.day], from: stored, to: now).day
    }()

    let total = interactions.count
    let sent = interactions.filter { $0.direction == .outbound }.count
    let received = total - sent
    let rate = total == 0 ? 0 : Int((Double(received) / Double(total) * 100).rounded())

    let preferred: InteractionType? = {
      guard !interactions.isEmpty else { return nil }
      var counts: [InteractionType: Int] = [:]
      var order: [InteractionType] = []
      for interaction in interactions where counts[interaction.type] == nil { order.append(interaction.type) }
      for interaction in interactions { counts[interaction.type, default: 0] += 1 }
      return order.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) })
    }()

    return CoachInsights(
      daysSinceContact: days,
      isOverdue: (days ?? Int.min) > overdueDays,
      totalInteractions: total,
      sent: sent,
      received: received,
      responseRate: rate,
      preferredChannel: preferred)
  }
}
