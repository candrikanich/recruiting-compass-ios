import Foundation
@testable import TheRecruitingCompass

final class MockTimelineStatusService: TimelineStatusManaging, @unchecked Sendable {
  var stubbedStatusScore = StatusScore(score: 0, label: .atRisk)
  var shouldThrowError = false

  var fetchCallCount = 0
  var lastAthleteId: String?
  var lastCompletedTaskIds: [String]?
  var lastAllRequiredTaskIds: [String]?

  func fetchStatusScore(
    athleteId: String,
    completedTaskIds: [String],
    allRequiredTaskIds: [String]
  ) async throws -> StatusScore {
    fetchCallCount += 1
    lastAthleteId = athleteId
    lastCompletedTaskIds = completedTaskIds
    lastAllRequiredTaskIds = allRequiredTaskIds

    if shouldThrowError {
      throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
    }

    return stubbedStatusScore
  }
}
