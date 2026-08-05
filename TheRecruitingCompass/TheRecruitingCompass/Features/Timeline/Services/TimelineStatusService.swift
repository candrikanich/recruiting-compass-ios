import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "TimelineStatusService")

/// Thresholds for status labels (matches web statusScoreCalculation.ts).
private enum StatusThresholds {
  static let onTrack = 75
  static let slightlyBehind = 50
}

/// Simplified client-side status calculation. Uses task completion as primary factor.
/// Other factors (interactions, coach interest, academic) can be added later via Supabase RPC.
final class TimelineStatusService: TimelineStatusManaging, Sendable {
  func fetchStatusScore(
    athleteId: String,
    completedTaskIds: [String],
    allRequiredTaskIds: [String]
  ) async throws -> StatusScore {
    let taskCompletionRate = calculateTaskCompletionRate(
      completedTaskIds: completedTaskIds,
      requiredTaskIds: allRequiredTaskIds
    )
    let score = Int(round(taskCompletionRate))
    let label = Self.getStatusLabel(score: score)
    let breakdown = StatusScoreBreakdown(
      taskCompletionRate: taskCompletionRate,
      interactionFrequencyScore: 0,
      coachInterestScore: 0,
      academicStandingScore: 0
    )
    logger.debug("Status for athlete \(athleteId): \(score)/100 (\(label.rawValue))")
    return StatusScore(score: score, label: label, breakdown: breakdown)
  }

  private func calculateTaskCompletionRate(
    completedTaskIds: [String],
    requiredTaskIds: [String]
  ) -> Double {
    guard !requiredTaskIds.isEmpty else { return 0 }
    let completed = requiredTaskIds.count(where: { completedTaskIds.contains($0) })
    return (Double(completed) / Double(requiredTaskIds.count)) * 100
  }

  private static func getStatusLabel(score: Int) -> StatusLabel {
    if score >= StatusThresholds.onTrack {
      return .onTrack
    } else if score >= StatusThresholds.slightlyBehind {
      return .slightlyBehind
    } else {
      return .atRisk
    }
  }
}
