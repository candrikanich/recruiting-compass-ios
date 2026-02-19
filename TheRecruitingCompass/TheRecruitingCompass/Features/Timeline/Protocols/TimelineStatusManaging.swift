import Foundation

protocol TimelineStatusManaging: Sendable {
  /// Fetch or calculate status score for an athlete.
  func fetchStatusScore(
    athleteId: String,
    completedTaskIds: [String],
    allRequiredTaskIds: [String]
  ) async throws -> StatusScore
}
