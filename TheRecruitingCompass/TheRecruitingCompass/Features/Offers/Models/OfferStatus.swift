import SwiftUI

enum OfferStatus: String, Codable, CaseIterable, Sendable {
  case pending
  case accepted
  case declined
  case expired
  case unknown

  /// Raw value safe to send to the server; nil for the decode-only `unknown` fallback so the key is omitted.
  var serverValue: String? { self == .unknown ? nil : rawValue }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = OfferStatus(rawValue: rawValue) ?? .unknown
  }

  /// User-selectable values. Excludes `unknown`, a decode-only fallback.
  static var selectableCases: [OfferStatus] { allCases.filter { $0 != .unknown } }

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
