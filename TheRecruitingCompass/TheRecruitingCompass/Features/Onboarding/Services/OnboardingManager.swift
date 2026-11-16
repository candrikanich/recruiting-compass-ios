import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingManager")

/// Whether a user still has to go through onboarding. The completion flag write is best-effort on both
/// platforms, so a parent already in a family passes without it (web PR #1391 matches this rule).
enum OnboardingGate {
  static func needsOnboarding(
    role: UserRole?, flagComplete: Bool, isInFamily: Bool, inSessionParentSignup: Bool = false
  ) -> Bool {
    // A parent mid-wizard stays in it even after the wizard writes the completion flag, so the school step
    // that follows is not cut short by a re-evaluation.
    if inSessionParentSignup && role == .parent { return true }
    if flagComplete { return false }
    return role == .parent ? !isInFamily : true
  }
}

extension OnboardingGate {
  /// A parent who signed up in this session and has not finished onboarding is routed through the parent wizard.
  /// Never latches for a finished account, and once latched it holds until the wizard ends.
  static func latchesInSessionParentSignup(
    role: UserRole?, flagComplete: Bool, signedUpThisSession: Bool, alreadyLatched: Bool
  ) -> Bool {
    guard role == .parent else { return false }
    return alreadyLatched || (signedUpThisSession && !flagComplete)
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

  /// True from the moment a parent finishes signup in this session until the wizard is done. Signup now creates
  /// the family itself, so a new parent is already a member and the family rule alone would skip the wizard
  /// (web sends them to /onboarding/parent). Latched so a re-evaluation (joining, sport gate) can't eject them
  /// mid-flow; in memory only, so a cold launch never brings it back.
  private(set) var inSessionParentSignup = false

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
      inSessionParentSignup = OnboardingGate.latchesInSessionParentSignup(
        role: user.role, flagComplete: complete,
        signedUpThisSession: authManager.parentSignedUpThisSession, alreadyLatched: inSessionParentSignup
      )
      needsOnboarding = OnboardingGate.needsOnboarding(
        role: user.role, flagComplete: complete, isInFamily: isInFamily,
        inSessionParentSignup: inSessionParentSignup
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
    inSessionParentSignup = false
  }

  func markComplete() {
    inSessionParentSignup = false
    needsOnboarding = false
  }
}
