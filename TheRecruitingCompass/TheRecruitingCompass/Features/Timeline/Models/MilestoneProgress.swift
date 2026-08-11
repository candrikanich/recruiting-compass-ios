import Foundation

/// Progress toward advancing from current phase to the next.
struct MilestoneProgress: Decodable, Sendable {
  let phase: TimelinePhase
  let required: [String]
  let completed: [String]
  let remaining: [String]
  let percentComplete: Double

  var completedCount: Int { completed.count }
  var totalCount: Int { required.count }
}
