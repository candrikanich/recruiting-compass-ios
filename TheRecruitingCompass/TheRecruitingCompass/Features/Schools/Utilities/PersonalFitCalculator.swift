import Foundation

enum PersonalFitCalculator {

  static func calculate(athlete: PlayerDetails?, school: School) -> PersonalFitAnalysis {
    PersonalFitAnalysis(
      location: locationSignal(athleteState: athlete?.schoolState,
                               schoolState: school.academicInfo?.state ?? school.state),
      campusSize: campusSizeSignal(preference: athlete?.campusSizePreference?.lowercased(),
                                   studentSize: school.academicInfo?.studentSize),
      cost: costSignal(sensitivity: athlete?.costSensitivity?.lowercased(),
                       cost: school.academicInfo?.tuitionOutOfState
                             ?? school.academicInfo?.tuitionInState)
    )
  }

  static func overall(_ analysis: PersonalFitAnalysis) -> OverallPersonalFit? {
    let ranks: [Int] = analysis.orderedSignals.compactMap { signal in
      switch signal.strength {
      case .strong: return 2
      case .good: return 1
      case .stretch: return 0
      case .unknown: return nil
      }
    }
    guard !ranks.isEmpty else { return nil }
    let mean = Double(ranks.reduce(0, +)) / Double(ranks.count)
    let strength: OverallPersonalFit.Strength = mean >= 1.5 ? .strong : (mean >= 0.75 ? .good : .stretch)
    return OverallPersonalFit(strength: strength)
  }

  // MARK: - Signals

  private static func locationSignal(athleteState: String?, schoolState: String?) -> PersonalFitSignal {
    guard let athleteState, let schoolState else {
      return PersonalFitSignal(label: String(localized: "Location"), value: nil, strength: .unknown,
        explanation: String(localized: "Add your home state to see location fit."))
    }
    let sameState = athleteState == schoolState
    return PersonalFitSignal(
      label: String(localized: "Location"),
      value: sameState ? String(localized: "In-state")
                       : String(localized: "Out-of-state (\(schoolState))"),
      strength: sameState ? .strong : .stretch,
      explanation: sameState
        ? String(localized: "In-state tuition typically applies and you may have regional familiarity.")
        : String(localized: "Out-of-state — consider higher tuition costs and distance from home."))
  }

  private static func campusSizeSignal(preference: String?, studentSize: Int?) -> PersonalFitSignal {
    let label = String(localized: "Campus Size")
    guard let studentSize else {
      return PersonalFitSignal(label: label, value: nil, strength: .unknown,
        explanation: String(localized: "Campus size data not available for this school."))
    }
    let bucket: String = studentSize < 5000 ? "small" : (studentSize <= 25000 ? "medium" : "large")
    let display = String(localized: "\(bucketLabel(bucket)) (\(studentSize.formatted()) students)")
    guard let preference else {
      return PersonalFitSignal(label: label, value: display, strength: .unknown,
        explanation: String(localized: "Add your campus size preference in your profile to see fit."))
    }
    let matches = preference == bucket
    return PersonalFitSignal(label: label, value: display, strength: matches ? .strong : .stretch,
      explanation: matches
        ? String(localized: "Matches your \(preference) campus preference.")
        : String(localized: "This is a \(bucket) campus; you prefer \(preference)."))
  }

  private static func costSignal(sensitivity: String?, cost: Double?) -> PersonalFitSignal {
    let label = String(localized: "Cost")
    guard let cost else {
      return PersonalFitSignal(label: label, value: nil, strength: .unknown,
        explanation: String(localized: "Tuition data not available for this school."))
    }
    let display = String(localized: "$\(Int(cost).formatted())/yr")
    guard let sensitivity else {
      return PersonalFitSignal(label: label, value: display, strength: .unknown,
        explanation: String(localized: "Add your cost sensitivity in your profile to see fit."))
    }
    let (strength, explanation): (FitSignalStrength, String)
    switch sensitivity {
    case "high":
      if cost <= 20000 {
        (strength, explanation) = (.strong, String(localized: "Cost is well within range for your financial situation."))
      } else if cost <= 35000 {
        (strength, explanation) = (.good, String(localized: "Cost is manageable but factor in scholarship potential."))
      } else {
        (strength, explanation) = (.stretch, String(localized: "Cost may be a significant challenge — explore all aid options."))
      }
    case "medium":
      if cost <= 35000 {
        (strength, explanation) = (.strong, String(localized: "Cost is reasonable for your situation."))
      } else if cost <= 55000 {
        (strength, explanation) = (.good, String(localized: "Cost is on the higher end — factor in scholarship potential."))
      } else {
        (strength, explanation) = (.stretch, String(localized: "Cost is high — ensure scholarship options are explored."))
      }
    default: // "low"
      (strength, explanation) = (.strong, String(localized: "Cost is not a primary concern in your college search."))
    }
    return PersonalFitSignal(label: label, value: display, strength: strength, explanation: explanation)
  }

  private static func bucketLabel(_ bucket: String) -> String {
    switch bucket {
    case "small": return String(localized: "Small")
    case "medium": return String(localized: "Medium")
    default: return String(localized: "Large")
    }
  }
}
