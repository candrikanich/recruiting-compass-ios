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

  /// True when an authenticated player has finished full onboarding but still has a
  /// null/blank `primary_sport`. Distinct from `needsOnboarding` — it routes to the
  /// minimal `SportGateView`, not the full onboarding flow. Players only; never parents.
  var needsSportOnly = false

  private static let parentOnboardingCompleteKeyPrefix = "parent_onboarding_complete_"

  private let onboardingService: any OnboardingManaging
  private let authManager: any AuthManaging
  private let familyService: any FamilyManaging
  private let preferenceService: any PreferenceManaging

  init(
    onboardingService: (any OnboardingManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyService: (any FamilyManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil
  ) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.familyService = familyService ?? FamilyServiceImpl(supabaseManager: .shared)
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
  }

  /// Call when user becomes authenticated. Players check DB; parents check local "parent onboarding complete" flag.
  func loadStatus() async {
    guard let user = authManager.user else {
      needsOnboarding = false
      needsSportOnly = false
      return
    }

    // Parents use a different flow and are never sport-gated.
    needsSportOnly = false

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

      // Sport gate: even a "complete" player with a null/blank primary_sport must pick one.
      // Treat empty string as unset. Fails open (below) so a transient read error never locks out.
      let details: PlayerDetails? = try await preferenceService.fetchPreferences(category: .player)
      let sport = details?.primarySport?.trimmingCharacters(in: .whitespaces) ?? ""
      needsSportOnly = sport.isEmpty

      logger.debug("Player status: onboarding=\(self.needsOnboarding ?? false), sportOnly=\(self.needsSportOnly)")
    } catch {
      logger.error("Failed to check onboarding status: \(error.localizedDescription)")
      needsOnboarding = false
      needsSportOnly = false
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
