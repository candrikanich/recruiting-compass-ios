import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingManager")

/// Whether a user still has to go through onboarding. The completion flag write is best-effort on both
/// platforms, so a parent already in a family passes without it (web PR #1391 matches this rule).
enum OnboardingGate {
  static func needsOnboarding(role: UserRole, flagComplete: Bool, isInFamily: Bool) -> Bool {
    if flagComplete { return false }
    return role == .parent ? !isInFamily : true
  }
}

/// Holds onboarding gate state. Players must complete onboarding (the shared `onboarding_complete` flag);
/// parents pass with the flag or by being in a family (see `OnboardingGate`).
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

  /// Advanced by `reset()`; a status check only routes while its session is still current.
  private var session = 0

  private let onboardingService: any OnboardingManaging
  private let authManager: any AuthManaging
  private let preferenceService: any PreferenceManaging

  init(
    onboardingService: (any OnboardingManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil
  ) {
    self.onboardingService = onboardingService ?? OnboardingServiceImpl(supabaseManager: .shared)
    self.authManager = authManager ?? AuthManager.shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
  }

  /// Call when user becomes authenticated.
  func loadStatus(isInFamily: Bool) async {
    guard let user = authManager.user else {
      needsOnboarding = false
      needsSportOnly = false
      return
    }

    let loadSession = session

    needsSportOnly = false

    do {
      let complete = try await onboardingService.isOnboardingComplete(userId: user.id)
      guard loadSession == session else { return }
      needsOnboarding = OnboardingGate.needsOnboarding(
        role: user.role, flagComplete: complete, isInFamily: isInFamily
      )

      // Parents are never sport-gated: the sport lives on the linked athlete's preferences.
      guard user.role != .parent else { return }

      // Sport gate: even a "complete" player with a null/blank primary_sport must pick one.
      // Treat empty string as unset. Fails open (below) so a transient read error never locks out.
      let details: PlayerDetails? = try await preferenceService.fetchPreferences(category: .player)
      guard loadSession == session else { return }
      let sport = details?.primarySport?.trimmingCharacters(in: .whitespaces) ?? ""
      needsSportOnly = sport.isEmpty

      logger.debug("Player status: onboarding=\(self.needsOnboarding ?? false), sportOnly=\(self.needsSportOnly)")
    } catch {
      logger.error("Failed to check onboarding status: \(error.localizedDescription)")
      guard loadSession == session else { return }
      needsOnboarding = false
      needsSportOnly = false
    }
  }

  /// Back to "loading" so the next user is routed by their own status, not the previous user's.
  func reset() {
    session += 1
    needsOnboarding = nil
    needsSportOnly = false
  }

  func markComplete() {
    needsOnboarding = false
  }
}
