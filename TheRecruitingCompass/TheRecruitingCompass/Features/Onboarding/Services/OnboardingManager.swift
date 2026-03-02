import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingManager")

/// Holds onboarding gate state. Players must complete onboarding before seeing the dashboard.
/// Parents see a short parent onboarding (invite athlete wizard) once before dashboard, matching web.
@Observable
@MainActor
final class OnboardingManager {
  /// nil = loading, true = show onboarding, false = show dashboard
  var needsOnboarding: Bool?

  private static let parentOnboardingCompleteKeyPrefix = "parent_onboarding_complete_"

  private let onboardingService: any OnboardingManaging
  private let authManager: any AuthManaging

  init(
    onboardingService: (any OnboardingManaging)? = nil,
    authManager: (any AuthManaging)? = nil
  ) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
  }

  /// Call when user becomes authenticated. Players check DB; parents check local "parent onboarding complete" flag.
  func loadStatus() async {
    guard let user = authManager.user else {
      needsOnboarding = false
      return
    }

    if user.role == .parent {
      let key = Self.parentOnboardingCompleteKeyPrefix + user.id
      let complete = UserDefaults.standard.bool(forKey: key)
      needsOnboarding = !complete
      logger.debug("Parent onboarding status: needsOnboarding=\(self.needsOnboarding ?? false)")
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

  /// Call when parent completes or skips the parent onboarding wizard (so we don't show it again).
  func markParentOnboardingComplete() {
    guard let userId = authManager.user?.id else { return }
    UserDefaults.standard.set(true, forKey: Self.parentOnboardingCompleteKeyPrefix + userId)
    markComplete()
  }
}
