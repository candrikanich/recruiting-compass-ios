import Foundation

/// How a raw metric value renders (number only — callers append the unit).
/// Byte-identical with web `Format`. `.percent` renders the number without the
/// `%` sign (the sign is the unit). `.duration` renders MM:SS.hh from seconds.
enum Format: Equatable, Sendable {
  case decimal(digits: Int, dropLeadingZero: Bool)
  case integer
  case percent(digits: Int)
  case duration

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
