import Foundation

/// Recruiting phase (grade-year) derived from graduation year or milestone completion.
enum TimelinePhase: String, Codable, CaseIterable, Sendable {
  case freshman
  case sophomore
  case junior
  case senior
  case committed

  /// Grade level (9–12) associated with this phase.
  var gradeLevel: Int {
    switch self {
    case .freshman: return 9
    case .sophomore: return 10
    case .junior: return 11
    case .senior, .committed: return 12
    }
  }

  var displayLabel: String {
    switch self {
    case .freshman: return String(localized: "Freshman Year")
    case .sophomore: return String(localized: "Sophomore Year")
    case .junior: return String(localized: "Junior Year")
    case .senior: return String(localized: "Senior Year")
    case .committed: return String(localized: "Committed")
    }
  }

  var theme: String {
    switch self {
    case .freshman: return String(localized: "Foundation & Awareness")
    case .sophomore: return String(localized: "Exposure & Communication")
    case .junior: return String(localized: "Evaluation & Relationship Building")
    case .senior: return String(localized: "Commitment & Transition")
    case .committed: return String(localized: "Post-Commitment")
    }
  }

  /// Map grade (9–12) to phase. Committed must be determined separately (NLI signed).
  static func from(gradeLevel: Int) -> TimelinePhase {
    switch gradeLevel {
    case 9: return .freshman
    case 10: return .sophomore
    case 11: return .junior
    case 12: return .senior
    default: return min(12, max(9, gradeLevel)) == 9 ? .freshman : .senior
    }
  }
}
