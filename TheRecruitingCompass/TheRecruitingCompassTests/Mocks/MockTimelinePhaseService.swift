import Foundation
@testable import TheRecruitingCompass

final class MockTimelinePhaseService: TimelinePhaseManaging, @unchecked Sendable {
  var stubbedPhase: TimelinePhase = .freshman
  var stubbedMilestoneProgress = MilestoneProgress(
    phase: .freshman,
    required: [],
    completed: [],
    remaining: [],
    percentComplete: 0
  )
  var stubbedCanAdvance = false
  var shouldThrowError = false

  var fetchCallCount = 0
  var lastGraduationYear: Int?
  var lastCompletedTaskIds: [String]?
  var lastAthleteId: String?

  func fetchPhaseAndMilestoneProgress(
    graduationYear: Int?,
    completedTaskIds: [String],
    athleteId: String
  ) async throws -> (phase: TimelinePhase, milestoneProgress: MilestoneProgress, canAdvance: Bool) {
    fetchCallCount += 1
    lastGraduationYear = graduationYear
    lastCompletedTaskIds = completedTaskIds
    lastAthleteId = athleteId

    if shouldThrowError {
      throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
    }

    return (phase: stubbedPhase, milestoneProgress: stubbedMilestoneProgress, canAdvance: stubbedCanAdvance)
  }
}
