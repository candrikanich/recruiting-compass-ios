import Foundation

/// Pure Academic Fit computation. Mirrors web `calcTestScoreSignal`
/// (utils/fitScoreCalculation.ts). GPA is intentionally not used (web parity).
enum AcademicFitCalculator {
  static func calculate(athlete: PlayerDetails?, school: School) -> AcademicFitAnalysis {
    let info = school.academicInfo
    let sat = signal(test: String(localized: "SAT"), score: athlete?.satScore,
                     p25: info?.sat25th, p75: info?.sat75th)
    let act = signal(test: String(localized: "ACT"), score: athlete?.actScore,
                     p25: info?.act25th, p75: info?.act75th)
    let hasSchoolData = info?.sat25th != nil || info?.act25th != nil
    return AcademicFitAnalysis(sat: sat, act: act, hasSchoolData: hasSchoolData,
                               admissionRate: info?.admissionRate)
  }

  private static func signal(test: String, score: Int?, p25: Int?, p75: Int?)
    -> AcademicFitSignal {
    guard let score else {
      return AcademicFitSignal(
        label: test, value: nil, strength: .unknown,
        explanation: String(localized: "Add your \(test) score to your profile."))
    }
    guard let p25, let p75 else {
      return AcademicFitSignal(
        label: test, value: nil, strength: .unknown,
        explanation: String(localized: "No \(test) data available for this school."))
    }
    let strength: TestScoreStrength
    let phrase: String
    if score >= p75 {
      strength = .above
      phrase = String(localized: "\(score) is above their 75th percentile (\(p25)–\(p75)).")
    } else if score >= p25 {
      strength = .inRange
      phrase = String(localized: "\(score) falls within their typical range (\(p25)–\(p75)).")
    } else {
      strength = .below
      phrase = String(localized: "\(score) is below their 25th percentile (\(p25)–\(p75)).")
    }
    return AcademicFitSignal(label: test, value: nil, strength: strength, explanation: phrase)
  }
}
