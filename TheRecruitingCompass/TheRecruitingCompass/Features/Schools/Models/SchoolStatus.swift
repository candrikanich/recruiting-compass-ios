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
    }
  }
}
