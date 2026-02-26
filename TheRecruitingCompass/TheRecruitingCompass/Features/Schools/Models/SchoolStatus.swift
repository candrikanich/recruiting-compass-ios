import SwiftUI

enum SchoolStatus: String, Codable, CaseIterable, Sendable {
  case interested
  case contacted
  case campInvite = "camp_invite"
  case recruited
  case officialVisitInvited = "official_visit_invited"
  case officialVisitScheduled = "official_visit_scheduled"
  case offerReceived = "offer_received"
  case committed
  case notPursuing = "not_pursuing"
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = SchoolStatus(rawValue: rawValue) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .interested:
      return "Interested"
    case .contacted:
      return "Contacted"
    case .campInvite:
      return "Camp Invite"
    case .recruited:
      return "Recruited"
    case .officialVisitInvited:
      return "Official Visit Invited"
    case .officialVisitScheduled:
      return "Official Visit Scheduled"
    case .offerReceived:
      return "Offer Received"
    case .committed:
      return "Committed"
    case .notPursuing:
      return "Not Pursuing"
    case .unknown:
      return "Unknown"
    }
  }

  var badgeColor: Color {
    switch self {
    case .interested:
      return Color.gray
    case .contacted:
      return Color.blue
    case .campInvite:
      return Color.cyan
    case .recruited:
      return Color.purple
    case .officialVisitInvited:
      return Color.orange
    case .officialVisitScheduled:
      return Color.orange
    case .offerReceived:
      return Color.green
    case .committed:
      return Color.green
    case .notPursuing:
      return Color.red
    case .unknown:
      return Color.gray
    }
  }

  var badgeColors: (background: Color, text: Color) {
    switch self {
    case .interested:
      return (Color.blue.opacity(0.15), .blue)
    case .contacted:
      return (Color.gray.opacity(0.15), Color(white: 0.4))
    case .campInvite:
      return (Color.purple.opacity(0.15), .purple)
    case .recruited:
      return (Color.green.opacity(0.15), .green)
    case .officialVisitInvited:
      return (Color.yellow.opacity(0.3), Color(red: 0.7, green: 0.5, blue: 0.0))
    case .officialVisitScheduled:
      return (Color.orange.opacity(0.15), .orange)
    case .offerReceived:
      return (Color.red.opacity(0.15), .red)
    case .committed:
      return (Color(red: 0.13, green: 0.50, blue: 0.13), .white)
    case .notPursuing:
      return (Color.gray.opacity(0.3), Color(white: 0.4))
    case .unknown:
      return (Color.gray.opacity(0.15), Color(white: 0.4))
    }
  }
}
