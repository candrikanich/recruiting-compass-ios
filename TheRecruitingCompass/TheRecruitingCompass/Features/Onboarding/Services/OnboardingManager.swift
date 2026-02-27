import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingManager")

/// Holds onboarding gate state. Players must complete onboarding before seeing the dashboard.
@Observable
@MainActor
final class OnboardingManager {
  /// nil = loading, true = show onboarding, false = show dashboard
  var needsOnboarding: Bool?

  private let onboardingService: any OnboardingManaging
  private let authManager: any AuthManaging

  init(
    onboardingService: (any OnboardingManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  /// Call when user becomes authenticated. Parents skip onboarding; players check DB.
  func loadStatus() async {
    guard let user = authManager.user else {
      needsOnboarding = false
      return
    }

    guard user.role == .player else {
      needsOnboarding = false
      return
    }

    do {
      let complete = try await onboardingService.isOnboardingComplete(userId: user.id)
      needsOnboarding = !complete
      logger.debug("Onboarding status: needsOnboarding=\(self.needsOnboarding ?? false)")
    } catch {
      logger.error("Failed to check onboarding status: \(error.localizedDescription)")
      needsOnboarding = false
    }
  }

  func markComplete() {
    needsOnboarding = false
  }
}
