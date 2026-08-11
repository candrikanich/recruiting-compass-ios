import Foundation
@testable import TheRecruitingCompass

/// Stubs the shared web timeline endpoints for `TimelineViewModel` tests.
final class MockTimelineAPIService: TimelineAPIManaging, @unchecked Sendable {
  var stubbedPhase: TimelinePhase = .freshman
  var stubbedMilestoneProgress = MilestoneProgress(
    phase: .freshman,
    required: [],
    completed: [],
    remaining: [],
    percentComplete: 0
  )
  var stubbedCanAdvance = false
  var stubbedStatusScore = 0
  var stubbedStatusLabel: StatusLabel = .atRisk
  var stubbedStatusColor = "red"
  var stubbedBreakdown = StatusScoreBreakdown(
    taskCompletionRate: 0,
    interactionFrequencyScore: 0,
    coachInterestScore: 0,
    academicStandingScore: 0
  )
  var stubbedWhatMatters: [WhatMattersItem] = []
  var shouldThrowError = false

  var phaseCallCount = 0
  var statusCallCount = 0
  var whatMattersCallCount = 0
  var lastAccessToken: String?

  func fetchPhase(accessToken: String?) async throws -> AthletePhaseResponse {
    phaseCallCount += 1
    lastAccessToken = accessToken
    try throwIfNeeded()
    return AthletePhaseResponse(
      phase: stubbedPhase,
      milestoneProgress: stubbedMilestoneProgress,
      canAdvance: stubbedCanAdvance
    )
  }

  func fetchStatus(accessToken: String?) async throws -> AthleteStatusResponse {
    statusCallCount += 1
    lastAccessToken = accessToken
    try throwIfNeeded()
    return AthleteStatusResponse(
      score: stubbedStatusScore,
      label: stubbedStatusLabel,
      color: stubbedStatusColor,
      breakdown: stubbedBreakdown
    )
  }

  func fetchWhatMattersNow(accessToken: String?) async throws -> [WhatMattersItem] {
    whatMattersCallCount += 1
    lastAccessToken = accessToken
    try throwIfNeeded()
    return stubbedWhatMatters
  }

  private func throwIfNeeded() throws {
    if shouldThrowError {
      throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
    }
  }
}
