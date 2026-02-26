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
    case .pending: return "Pending"
    case .accepted: return "Accepted"
    case .declined: return "Declined"
    case .expired: return "Expired"
    case .unknown: return "Unknown"
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
