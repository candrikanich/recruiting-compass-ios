import Foundation

/// Athlete test score vs a school's 25th–75th percentile range. Mirrors web
/// `TestScoreStrength` in types/schoolFit.ts.
enum TestScoreStrength: String, Sendable, Equatable {
  case above
  case inRange
  case below
  case unknown

  var label: String {
    switch self {
    case .above:   return String(localized: "Above range")
    case .inRange: return String(localized: "In range")
    case .below:   return String(localized: "Below range")
    case .unknown: return String(localized: "No data")
    }
  }

  var badgeColor: BadgeColor {
    switch self {
    case .above, .inRange: return .emerald
    case .below:           return .orange
    case .unknown:         return .slate
    }
  }
}

struct AcademicFitSignal: Sendable, Equatable {
  let label: String
  /// Reserved web-parity placeholder — not populated for academic signals; the display text lives in `explanation`.
  let value: String?
  let strength: TestScoreStrength
  let explanation: String
}

/// SAT + ACT comparison for one school. Mirrors web `calculateAcademicFitSignals`.
struct AcademicFitAnalysis: Sendable, Equatable {
  let sat: AcademicFitSignal
  let act: AcademicFitSignal
  /// True when the school has at least one percentile range (`sat_25th || act_25th`).
  let hasSchoolData: Bool
  let admissionRate: Double?

  var orderedSignals: [AcademicFitSignal] { [sat, act] }
  var availableSignals: Int { orderedSignals.filter { $0.strength != .unknown }.count }
}
