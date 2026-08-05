import Foundation

/// Milestone task IDs required to advance from one phase to the next (matches web phaseCalculation.ts).
enum PhaseMilestones {
  static let freshmanToSophomore = [
    "understand-academic-requirements",
    "establish-development-routine",
    "play-travel-ball",
    "research-division-levels"
  ]
  static let sophomoreToJunior = [
    "create-highlight-video",
    "maintain-strong-gpa-10",
    "build-target-school-list-20",
    "send-first-introductory-emails"
  ]
  static let juniorToSenior = [
    "register-with-ncaa-eligibility",
    "peak-athletic-performance-11",
    "increase-coach-communication",
    "film-multiple-game-performances"
  ]
  static let seniorToCommitted = ["sign-nli"]
}
