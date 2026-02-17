import SwiftUI

enum OfferStatus: String, Codable, CaseIterable, Sendable {
  case pending
  case accepted
  case declined
  case expired

  var displayName: String {
    switch self {
    case .pending: return "Pending"
    case .accepted: return "Accepted"
    case .declined: return "Declined"
    case .expired: return "Expired"
    }
  }

  var statusColor: Color {
    switch self {
    case .accepted: return .successGreen
    case .pending: return .accentBlue
    case .declined: return .errorRed
    case .expired: return .iconGray
    }
  }
}
