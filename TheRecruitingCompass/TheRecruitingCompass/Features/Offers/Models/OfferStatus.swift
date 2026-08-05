import SwiftUI

enum OfferStatus: String, Codable, CaseIterable, Sendable {
  case pending
  case accepted
  case declined
  case expired
  case unknown

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = OfferStatus(rawValue: rawValue) ?? .unknown
  }

  var displayName: String {
    switch self {
    case .pending: return String(localized: "Pending")
    case .accepted: return String(localized: "Accepted")
    case .declined: return String(localized: "Declined")
    case .expired: return String(localized: "Expired")
    case .unknown: return String(localized: "Unknown")
    }
  }

  var statusColor: Color {
    switch self {
    case .accepted: return .successGreen
    case .pending: return .accentBlue
    case .declined: return .errorRed
    case .expired: return .iconGray
    case .unknown: return .iconGray
    }
  }
}
