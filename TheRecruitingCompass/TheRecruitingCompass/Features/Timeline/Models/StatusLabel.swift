import Foundation

/// Status label derived from score (on_track / slightly_behind / at_risk).
enum StatusLabel: String, Codable, Sendable {
  case onTrack = "on_track"
  case slightlyBehind = "slightly_behind"
  case atRisk = "at_risk"
  case unknown

  /// Raw value safe to send to the server; nil for the decode-only `unknown` fallback so the key is omitted.
  var serverValue: String? { self == .unknown ? nil : rawValue }

  init(from decoder: Decoder) throws {
    let rawValue = try decoder.singleValueContainer().decode(String.self)
    self = StatusLabel(rawValue: rawValue) ?? .unknown
  }
}
