import Foundation

/// Reads the shared web timeline endpoints (phase / status / what-matters-now).
/// The endpoints resolve viewer→athlete server-side (parent→linked player), so
/// only the Supabase bearer token is passed; iOS supplies no athlete id.
protocol TimelineAPIManaging: Sendable {
  func fetchPhase(accessToken: String?, athleteId: String?) async throws -> AthletePhaseResponse
  func fetchStatus(accessToken: String?, athleteId: String?) async throws -> AthleteStatusResponse
  func fetchWhatMattersNow(accessToken: String?, athleteId: String?) async throws -> [WhatMattersItem]
}
