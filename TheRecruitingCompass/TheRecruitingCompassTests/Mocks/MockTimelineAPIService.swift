import Foundation
import os
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

  /// Awaited inside `fetchPhase` so tests can hold a load in flight.
  var fetchPhaseGate: (@Sendable () async -> Void)?

  // `fetchSummary` runs the three fetches as concurrent `async let`s, so every recorded call is lock-guarded.
  private struct Recorded {
    var phaseCallCount = 0
    var statusCallCount = 0
    var whatMattersCallCount = 0
    var lastAccessToken: String?
    var requestedAthleteIds: [String?] = []
  }

  private let recorded = OSAllocatedUnfairLock(initialState: Recorded())

  var phaseCallCount: Int { recorded.withLock { $0.phaseCallCount } }
  var statusCallCount: Int { recorded.withLock { $0.statusCallCount } }
  var whatMattersCallCount: Int { recorded.withLock { $0.whatMattersCallCount } }
  var lastAccessToken: String? { recorded.withLock { $0.lastAccessToken } }
  var requestedAthleteIds: [String?] { recorded.withLock { $0.requestedAthleteIds } }

  private func record(_ keyPath: WritableKeyPath<Recorded, Int>, accessToken: String?, athleteId: String?) {
    recorded.withLock {
      $0[keyPath: keyPath] += 1
      $0.requestedAthleteIds.append(athleteId)
      $0.lastAccessToken = accessToken
    }
  }

  func fetchPhase(accessToken: String?, athleteId: String?) async throws -> AthletePhaseResponse {
    record(\.phaseCallCount, accessToken: accessToken, athleteId: athleteId)
    await fetchPhaseGate?()
    try throwIfNeeded()
    return AthletePhaseResponse(
      phase: stubbedPhase,
      milestoneProgress: stubbedMilestoneProgress,
      canAdvance: stubbedCanAdvance
    )
  }

  func fetchStatus(accessToken: String?, athleteId: String?) async throws -> AthleteStatusResponse {
    record(\.statusCallCount, accessToken: accessToken, athleteId: athleteId)
    try throwIfNeeded()
    return AthleteStatusResponse(
      score: stubbedStatusScore,
      label: stubbedStatusLabel,
      color: stubbedStatusColor,
      breakdown: stubbedBreakdown
    )
  }

  func fetchWhatMattersNow(accessToken: String?, athleteId: String?) async throws -> [WhatMattersItem] {
    record(\.whatMattersCallCount, accessToken: accessToken, athleteId: athleteId)
    try throwIfNeeded()
    return stubbedWhatMatters
  }

  private func throwIfNeeded() throws {
    if shouldThrowError {
      throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
    }
  }
}
