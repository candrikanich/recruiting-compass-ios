import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "TimelinePhaseService")

/// Milestone task IDs required to advance from one phase to the next (matches web phaseCalculation.ts).
enum PhaseMilestones {
  static let freshmanToSophomore = [
    "understand-academic-requirements",
    "establish-development-routine",
    "play-travel-ball",
    "research-division-levels",
  ]
  static let sophomoreToJunior = [
    "create-highlight-video",
    "maintain-strong-gpa-10",
    "build-target-school-list-20",
    "send-first-introductory-emails",
  ]
  static let juniorToSenior = [
    "register-with-ncaa-eligibility",
    "peak-athletic-performance-11",
    "increase-coach-communication",
    "film-multiple-game-performances",
  ]
  static let seniorToCommitted = ["sign-nli"]
}

final class TimelinePhaseService: TimelinePhaseManaging, Sendable {
  func fetchPhaseAndMilestoneProgress(
    graduationYear: Int?,
    completedTaskIds: [String],
    athleteId: String
  ) async throws -> (phase: TimelinePhase, milestoneProgress: MilestoneProgress, canAdvance: Bool) {
    let completed = Set(completedTaskIds)
    let hasSignedNLI = completed.contains("sign-nli")

    let phase = Self.calculatePhase(completedTaskIds: completedTaskIds, hasSignedNLI: hasSignedNLI, graduationYear: graduationYear)
    let milestoneProgress = Self.getMilestoneProgress(phase: phase, completedTaskIds: completedTaskIds)
    let canAdvance = Self.canAdvancePhase(currentPhase: phase, completedTaskIds: completedTaskIds)

    logger.debug("Phase for athlete \(athleteId): \(phase.rawValue), canAdvance: \(canAdvance)")
    return (phase, milestoneProgress, canAdvance)
  }

  private static func calculatePhase(
    completedTaskIds: [String],
    hasSignedNLI: Bool,
    graduationYear: Int?
  ) -> TimelinePhase {
    if hasSignedNLI { return .committed }

    let completed = Set(completedTaskIds)

    if PhaseMilestones.juniorToSenior.allSatisfy({ completed.contains($0) }) {
      return .senior
    }
    if PhaseMilestones.sophomoreToJunior.allSatisfy({ completed.contains($0) }) {
      return .junior
    }
    if PhaseMilestones.freshmanToSophomore.allSatisfy({ completed.contains($0) }) {
      return .sophomore
    }

    if let year = graduationYear {
      let grade = GradeLevelHelper.calculateCurrentGrade(graduationYear: year)
      return TimelinePhase.from(gradeLevel: grade)
    }
    return .freshman
  }

  private static func getMilestoneProgress(phase: TimelinePhase, completedTaskIds: [String]) -> MilestoneProgress {
    let completed = Set(completedTaskIds)

    let required: [String]
    switch phase {
    case .freshman:
      required = PhaseMilestones.freshmanToSophomore
    case .sophomore:
      required = PhaseMilestones.sophomoreToJunior
    case .junior:
      required = PhaseMilestones.juniorToSenior
    case .senior:
      required = PhaseMilestones.seniorToCommitted
    case .committed:
      return MilestoneProgress(phase: .committed, required: [], completed: [], remaining: [], percentComplete: 100)
    }

    let completedList = required.filter { completed.contains($0) }
    let remaining = required.filter { !completed.contains($0) }
    let percentComplete = required.isEmpty ? 0 : (Double(completedList.count) / Double(required.count)) * 100

    return MilestoneProgress(
      phase: phase,
      required: required,
      completed: completedList,
      remaining: remaining,
      percentComplete: percentComplete
    )
  }

  private static func canAdvancePhase(currentPhase: TimelinePhase, completedTaskIds: [String]) -> Bool {
    let completed = Set(completedTaskIds)
    switch currentPhase {
    case .freshman:
      return PhaseMilestones.freshmanToSophomore.allSatisfy { completed.contains($0) }
    case .sophomore:
      return PhaseMilestones.sophomoreToJunior.allSatisfy { completed.contains($0) }
    case .junior:
      return PhaseMilestones.juniorToSenior.allSatisfy { completed.contains($0) }
    case .senior:
      return PhaseMilestones.seniorToCommitted.allSatisfy { completed.contains($0) }
    case .committed:
      return false
    }
  }
}
