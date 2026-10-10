import Foundation

enum NotificationType: String, Codable, CaseIterable, Sendable {
  case followUpReminder = "follow_up_reminder"
  case deadlineAlert = "deadline_alert"
  case weeklyDigest = "weekly_digest"
  case inboundInteraction = "inbound_interaction"
  case offer
  case event
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    // Live cron / generator still insert `daily_digest` after the preferences
    // CHECK was renamed to `weekly_digest`. Treat both as the digest type so
    // the inbox does not dump those rows into `.unknown`.
    if rawValue == "daily_digest" {
      self = .weeklyDigest
      return
    }
    self = NotificationType(rawValue: rawValue) ?? .unknown
  }

  var label: String {
    switch self {
    case .followUpReminder: return String(localized: "Follow-ups")
    case .deadlineAlert: return String(localized: "Deadlines")
    case .weeklyDigest: return String(localized: "Digest")
    case .inboundInteraction: return String(localized: "Inbound")
    case .offer: return String(localized: "Offers")
    case .event: return String(localized: "Events")
    case .unknown: return String(localized: "Other")
    }
  }

  var systemImage: String {
    switch self {
    case .followUpReminder: return "bell.fill"
    case .deadlineAlert: return "clock"
    case .weeklyDigest: return "chart.bar"
    case .inboundInteraction: return "envelope"
    case .offer: return "trophy"
    case .event: return "calendar"
    case .unknown: return "tray"
    }
  }
}
