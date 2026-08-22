import Foundation

/// How a raw metric value renders (number only — callers append the unit).
/// Byte-identical with web `Format`. `.percent` renders the number without the
/// `%` sign (the sign is the unit). `.duration` renders MM:SS.hh from seconds.
enum Format: Equatable, Sendable {
  case decimal(digits: Int, dropLeadingZero: Bool)
  case integer
  case percent(digits: Int)
  case duration

  /// Fraction-digit count this format renders with, for pre-filling an editable
  /// value field at the metric's real precision (e.g. 3 for on_base_pct). Whole
  /// counts render with none; durations pre-fill at 2 for the raw-seconds field.
  var fractionDigits: Int {
    switch self {
    case let .decimal(digits, _): return digits
    case let .percent(digits): return digits
    case .integer: return 0
    case .duration: return 2
    }
  }

  func apply(_ value: Double) -> String {
    switch self {
    case let .decimal(digits, dropLeadingZero):
      let s = String(format: "%.\(digits)f", value)
      if dropLeadingZero, s.hasPrefix("0.") { return String(s.dropFirst()) }
      return s
    case .integer:
      return String(Int(value.rounded()))
    case let .percent(digits):
      return String(format: "%.\(digits)f", value)
    case .duration:
      let totalHundredths = (value * 100).rounded()
      let minutes = Int(totalHundredths) / 6000
      let seconds = (Int(totalHundredths) % 6000) / 100
      let hundredths = Int(totalHundredths) % 100
      return String(format: "%d:%02d.%02d", minutes, seconds, hundredths)
    }
  }
}
