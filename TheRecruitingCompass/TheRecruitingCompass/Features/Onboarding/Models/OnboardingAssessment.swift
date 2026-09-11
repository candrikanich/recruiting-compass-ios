import Foundation

/// Assessment responses for onboarding completion. Mirrors web useOnboarding.OnboardingAssessment.
struct OnboardingAssessment: Codable, Sendable {
  var hasHighlightVideo: Bool = false
  var hasContactedCoaches: Bool = false
  var hasTargetSchools: Bool = false
  var hasRegisteredEligibility: Bool = false
  var hasTakenTestScores: Bool = false

  enum CodingKeys: String, CodingKey {
    case hasHighlightVideo
    case hasContactedCoaches
    case hasTargetSchools
    case hasRegisteredEligibility
    case hasTakenTestScores
  }

  static let defaultForOnboarding: OnboardingAssessment = OnboardingAssessment()

  private static let phaseRank: [String: Int] = ["freshman": 0, "sophomore": 1, "junior": 2, "senior": 3]

  /// Determines the starting phase to persist at onboarding completion. Mirrors web
  /// useOnboarding.calculateStartingPhase: combines the assessment questionnaire signal
  /// with the grade derived from `graduationYear`, taking whichever is further along.
  /// Never regresses below the athlete's actual grade level — a freshman-grade athlete
  /// with no assessment signal still starts "freshman", but a junior-grade athlete with
  /// no assessment signal starts "junior", not "freshman".
  static func startingPhase(for assessment: OnboardingAssessment, graduationYear: Int?) -> String {
    var assessmentPhase = "freshman"
    if assessment.hasRegisteredEligibility || assessment.hasTakenTestScores {
      assessmentPhase = "junior"
    } else if assessment.hasHighlightVideo && assessment.hasTargetSchools {
      assessmentPhase = "sophomore"
    }

    guard let graduationYear else { return assessmentPhase }

    let gradeDerivedPhase = GradeLevelHelper.phase(forGrade: GradeLevelHelper.calculateCurrentGrade(graduationYear: graduationYear))
    let gradeRank = phaseRank[gradeDerivedPhase] ?? 0
    let assessmentRank = phaseRank[assessmentPhase] ?? 0
    return gradeRank > assessmentRank ? gradeDerivedPhase : assessmentPhase
  }
}
