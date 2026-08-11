import Foundation

/// Decodable responses for the shared web timeline endpoints. iOS consumes these
/// as the single source of truth instead of recomputing phase/score/current-task
/// locally. See `planning/iOS_SPEC_timeline-sync-shared-endpoints-2026-08-11.md`.

/// `GET /api/athlete/phase`
struct AthletePhaseResponse: Decodable, Sendable {
  let phase: TimelinePhase
  let milestoneProgress: MilestoneProgress
  let canAdvance: Bool
}

/// `GET /api/athlete/status` — the authoritative 4-factor composite score.
struct AthleteStatusResponse: Decodable, Sendable {
  let score: Int
  let label: StatusLabel
  let color: String
  let breakdown: StatusScoreBreakdown
}

/// One item from `GET /api/athlete/what-matters-now` (prioritized, highest first).
/// The timeline card uses `[0]`.
struct WhatMattersItem: Decodable, Sendable, Identifiable {
  let taskId: String
  let title: String
  let whyItMatters: String
  let category: String
  let priority: Int
  let isRequired: Bool

  var id: String { taskId }
}
