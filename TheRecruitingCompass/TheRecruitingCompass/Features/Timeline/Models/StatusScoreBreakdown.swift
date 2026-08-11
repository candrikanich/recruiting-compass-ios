import Foundation

struct StatusScoreBreakdown: Decodable, Sendable {
  let taskCompletionRate: Double
  let interactionFrequencyScore: Double
  let coachInterestScore: Double
  let academicStandingScore: Double
}
