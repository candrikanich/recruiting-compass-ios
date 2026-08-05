import Foundation

enum OfferType: String, Codable, CaseIterable, Sendable {
  case fullRide = "full_ride"
  case partial
  case scholarship
  case recruitedWalkOn = "recruited_walk_on"
  case preferredWalkOn = "preferred_walk_on"
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = OfferType(rawValue: rawValue) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .fullRide: return String(localized: "Full Ride")
    case .partial: return String(localized: "Partial")
    case .scholarship: return String(localized: "Scholarship")
    case .recruitedWalkOn: return String(localized: "Recruited Walk-On")
    case .preferredWalkOn: return String(localized: "Preferred Walk-On")
    case .unknown: return String(localized: "Unknown")
    }
  }
}
