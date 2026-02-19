import Foundation

protocol TimelinePhaseManaging: Sendable {
  /// Fetch current phase and milestone progress for an athlete.
  /// - Parameters:
  ///   - graduationYear: From user preferences; used to derive grade and phase when milestones unavailable
  ///   - completedTaskIds: Task IDs the athlete has completed
  ///   - hasSignedNLI: Whether athlete has completed the NLI signing task
  func fetchPhaseAndMilestoneProgress(
    graduationYear: Int?,
    completedTaskIds: [String],
    athleteId: String
  ) async throws -> (phase: TimelinePhase, milestoneProgress: MilestoneProgress, canAdvance: Bool)
}
