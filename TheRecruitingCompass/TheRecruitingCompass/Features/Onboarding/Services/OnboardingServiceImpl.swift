import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingService")

/// Sendable: Stateless service with no mutable properties
final class OnboardingServiceImpl: OnboardingManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func isOnboardingComplete(userId: String) async throws -> Bool {
    struct PhaseMilestoneRow: Codable {
      let phaseMilestoneData: PhaseMilestoneData?

      enum CodingKeys: String, CodingKey {
        case phaseMilestoneData = "phase_milestone_data"
      }

      struct PhaseMilestoneData: Codable {
        let onboardingComplete: Bool?

        enum CodingKeys: String, CodingKey {
          case onboardingComplete = "onboarding_complete"
        }
      }
    }

    let rows: [PhaseMilestoneRow] = try await supabaseManager.client
      .from("users")
      .select("phase_milestone_data")
      .eq("id", value: userId)
      .limit(1)
      .execute()
      .value

    guard let row = rows.first else { return false }
    return row.phaseMilestoneData?.onboardingComplete == true
  }

  func completeOnboarding(
    userId: String,
    assessment: OnboardingAssessment,
    startingPhase: String
  ) async throws {
    struct UpdatePayload: Encodable {
      let currentPhase: String
      let phaseMilestoneData: PhaseMilestonePayload

      enum CodingKeys: String, CodingKey {
        case currentPhase = "current_phase"
        case phaseMilestoneData = "phase_milestone_data"
      }

      struct PhaseMilestonePayload: Encodable {
        let onboardingComplete: Bool
        let onboardingCompletedAt: String
        let assessmentResponses: AssessmentPayload

        enum CodingKeys: String, CodingKey {
          case onboardingComplete = "onboarding_complete"
          case onboardingCompletedAt = "onboarding_completed_at"
          case assessmentResponses = "assessment_responses"
        }

        struct AssessmentPayload: Encodable {
          let hasHighlightVideo: Bool
          let hasContactedCoaches: Bool
          let hasTargetSchools: Bool
          let hasRegisteredEligibility: Bool
          let hasTakenTestScores: Bool
        }
      }
    }

    let payload = UpdatePayload(
      currentPhase: startingPhase,
      phaseMilestoneData: UpdatePayload.PhaseMilestonePayload(
        onboardingComplete: true,
        onboardingCompletedAt: ISO8601DateFormatter().string(from: Date()),
        assessmentResponses: UpdatePayload.PhaseMilestonePayload.AssessmentPayload(
          hasHighlightVideo: assessment.hasHighlightVideo,
          hasContactedCoaches: assessment.hasContactedCoaches,
          hasTargetSchools: assessment.hasTargetSchools,
          hasRegisteredEligibility: assessment.hasRegisteredEligibility,
          hasTakenTestScores: assessment.hasTakenTestScores
        )
      )
    )

    try await supabaseManager.client
      .from("users")
      .update(payload)
      .eq("id", value: userId)
      .execute()

    logger.info("Onboarding completed for user \(userId), phase: \(startingPhase)")
  }
}
