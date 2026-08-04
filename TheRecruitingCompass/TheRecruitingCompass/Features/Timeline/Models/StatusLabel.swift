import Foundation

/// Status label derived from score (on_track / slightly_behind / at_risk).
enum StatusLabel: String, Codable, Sendable {
  case onTrack = "on_track"
  case slightlyBehind = "slightly_behind"
  case atRisk = "at_risk"
}
