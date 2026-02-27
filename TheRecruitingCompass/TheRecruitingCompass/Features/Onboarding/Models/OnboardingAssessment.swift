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
}
