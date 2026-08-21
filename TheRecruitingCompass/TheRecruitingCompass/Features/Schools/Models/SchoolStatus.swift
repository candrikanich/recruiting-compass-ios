import Foundation

/// Recruiting-pipeline stage for a school. Canonical funnel is monotonic:
/// `researching → contacted → visiting → offer_received → committed`, with
/// `not_pursuing` as a terminal off-ramp. Kept in lock-step with the web
/// `SCHOOL_STATUS_OPTIONS` list (utils/schoolStatusOptions.ts).
///
/// Affinity ("I like this school") is NOT a status — it lives on the favorite
/// flag. The former `interested` stage was folded into favorite; the visit/camp
/// granularity (`camp_invite`, `official_visit_*`, `recruited`) collapsed into
/// `visiting`. Those deprecated cases are retained only so legacy rows still
/// decode; they are excluded from `pipeline`/`selectable` and never offered in
/// the UI. See planning/2026-08-21-school-status-pipeline-spec.md.
enum SchoolStatus: String, Codable, CaseIterable, Sendable {
  // Canonical progress stages (in funnel order).
  case researching
  case contacted
  case visiting
  case offerReceived = "offer_received"
  case committed
  // Terminal off-ramp.
  case notPursuing = "not_pursuing"

  // Deprecated — retained for decoding legacy data only (DB migrated away).
  case interested
  case campInvite = "camp_invite"
  case recruited
  case officialVisitInvited = "official_visit_invited"
  case officialVisitScheduled = "official_visit_scheduled"
  case unknown

  /// Canonical progress pipeline, in monotonic funnel order.
  static let pipeline: [SchoolStatus] = [.researching, .contacted, .visiting, .offerReceived, .committed]

  /// Terminal off-ramp stage (a school no longer being pursued).
  static let offRamp: SchoolStatus = .notPursuing

  /// User-selectable statuses in canonical order (pipeline + off-ramp).
  /// Use this for every picker/filter — never `allCases`, which includes
  /// deprecated decode-only values.
  static let selectable: [SchoolStatus] = pipeline + [offRamp]

  /// Monotonic rank within the progress funnel; the off-ramp sorts last.
  /// Deprecated values map to their canonical replacement's rank.
  var rank: Int {
    switch self {
    case .researching, .interested, .unknown: return 0
    case .contacted: return 1
    case .visiting, .campInvite, .recruited, .officialVisitInvited, .officialVisitScheduled: return 2
    case .offerReceived: return 3
    case .committed: return 4
    case .notPursuing: return 99
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = SchoolStatus(rawValue: rawValue) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .researching:
      return String(localized: "Researching")
    case .interested:
      return String(localized: "Interested")
    case .contacted:
      return String(localized: "Contacted")
    case .visiting:
      return String(localized: "Visiting")
    case .campInvite:
      return String(localized: "Camp Invite")
    case .recruited:
      return String(localized: "Recruited")
    case .officialVisitInvited:
      return String(localized: "Official Visit Invited")
    case .officialVisitScheduled:
      return String(localized: "Official Visit Scheduled")
    case .offerReceived:
      return String(localized: "Offer Received")
    case .committed:
      return String(localized: "Committed")
    case .notPursuing:
      return String(localized: "Not Pursuing")
    case .unknown:
      return String(localized: "Unknown")
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .researching:            return .slate
    case .interested:             return .slate
    case .contacted:              return .blue
    case .visiting:               return .orange
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
