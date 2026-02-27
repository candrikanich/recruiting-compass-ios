import Foundation

protocol OnboardingManaging: Sendable {
  /// Returns true if user has completed onboarding (phase_milestone_data.onboarding_complete).
  func isOnboardingComplete(userId: String) async throws -> Bool

  /// Marks onboarding complete: updates users.current_phase and phase_milestone_data.
  /// Mirrors web useOnboarding.completeOnboarding.
  func completeOnboarding(
    userId: String,
    assessment: OnboardingAssessment,
    startingPhase: String
  ) async throws
}
