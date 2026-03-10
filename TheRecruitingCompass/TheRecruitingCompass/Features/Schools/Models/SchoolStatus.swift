import Foundation

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

  var badgeColor: BadgeColor {
    switch self {
    case .interested:             return .slate
    case .contacted:              return .blue
    case .campInvite:             return .purple
    case .recruited:              return .emerald
    case .officialVisitInvited:   return .orange
    case .officialVisitScheduled: return .orange
    case .offerReceived:          return .emerald
    case .committed:              return .emerald
    case .notPursuing:            return .red
    case .unknown:                return .slate
    }
  }
}
