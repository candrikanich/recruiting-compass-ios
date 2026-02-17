import Foundation

enum OfferType: String, Codable, CaseIterable, Sendable {
  case fullRide = "full_ride"
  case partial
  case scholarship
  case recruitedWalkOn = "recruited_walk_on"
  case preferredWalkOn = "preferred_walk_on"

  var displayName: String {
    switch self {
    case .fullRide: return "Full Ride"
    case .partial: return "Partial"
    case .scholarship: return "Scholarship"
    case .recruitedWalkOn: return "Recruited Walk-On"
    case .preferredWalkOn: return "Preferred Walk-On"
    }
  }
}
