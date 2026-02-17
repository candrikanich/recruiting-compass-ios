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
    case .accepted: return Color(hex: "10b981")
    case .pending: return Color(hex: "3b82f6")
    case .declined: return Color(hex: "ef4444")
    case .expired: return Color(hex: "6b7280")
    }
  }
}
