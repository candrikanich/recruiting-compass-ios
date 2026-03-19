import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingManager")

/// Holds onboarding gate state. Players must complete onboarding before seeing the dashboard.
/// Parents see a short parent onboarding (invite athlete wizard) once before dashboard, matching web.
@Observable
@MainActor
final class OnboardingManager {
  nonisolated deinit {}
  /// nil = loading, true = show onboarding, false = show dashboard
  var needsOnboarding: Bool?

  private static let parentOnboardingCompleteKeyPrefix = "parent_onboarding_complete_"

  private let onboardingService: any OnboardingManaging
  private let authManager: any AuthManaging
  private let familyService: any FamilyManaging

  init(
    onboardingService: (any OnboardingManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyService: (any FamilyManaging)? = nil
  ) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
  }

  /// Call when user becomes authenticated. Players check DB; parents check local "parent onboarding complete" flag.
  func loadStatus() async {
    guard let user = authManager.user else {
      needsOnboarding = false
      return
    }

    if user.role == .parent {
      let key = Self.parentOnboardingCompleteKeyPrefix + user.id

      // Fast-path: if already cached on this device, skip the DB call
      if UserDefaults.standard.bool(forKey: key) {
        needsOnboarding = false
        logger.debug("Parent onboarding: cached complete on device")
        return
      }

      // DB check: if the parent already has a family, they've done onboarding
      do {
        let existingFamily = try await familyService.getFamilyUnit(forUserId: user.id)
        if existingFamily != nil {
          // Write cache so future launches skip this DB call
          UserDefaults.standard.set(true, forKey: key)
          needsOnboarding = false
          logger.debug("Parent onboarding: family found in DB, marking complete")
        } else {
          needsOnboarding = true
          logger.debug("Parent onboarding: no family found, showing onboarding")
        }
      } catch {
        // Fail-safe: prefer dashboard access over blocking the user on a transient
        // network failure. A parent who truly needs onboarding will see it on next
        // successful launch when the DB check succeeds.
        logger.error("Parent onboarding DB check failed: \(error.localizedDescription)")
        needsOnboarding = false
      }
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
