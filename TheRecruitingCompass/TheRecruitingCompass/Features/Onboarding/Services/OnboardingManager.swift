import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "OnboardingManager")

/// Whether a user still has to go through onboarding. The completion flag write is best-effort on both
/// platforms, so a parent already in a family passes without it (web PR #1391 matches this rule).
enum OnboardingGate {
  static func needsOnboarding(
    role: UserRole?, flagComplete: Bool, isInFamily: Bool, parentFirstRun: ParentFirstRun? = nil
  ) -> Bool {
    // A parent mid-wizard stays in it even after the wizard writes the completion flag, so the school step
    // that follows is not cut short by a re-evaluation.
    if parentFirstRun != nil && role == .parent { return true }
    if flagComplete { return false }
    return role == .parent ? !isInFamily : true
  }
}

/// What a parent who signed up in this session sees first, matching web: an ordinary signup goes through the
/// parent wizard (`/onboarding/parent`); an invited parent, whose family already exists, goes to the school
/// step only (`/onboarding?step=school`), and only when the accept left onboarding incomplete.
enum ParentFirstRun: Equatable {
  case wizard
  case schoolStepOnly
}

extension OnboardingGate {
  /// Never latches for a finished account, and once latched it holds until `markComplete()`, so a
  /// re-evaluation (membership change, sport gate, the wizard writing the completion flag) can't cut it short.
  static func parentFirstRun(
    role: UserRole?, flagComplete: Bool, signup: ParentSignupKind?, latched: ParentFirstRun?
  ) -> ParentFirstRun? {
    guard role == .parent else { return nil }
    if let latched { return latched }
    guard !flagComplete, let signup else { return nil }
    return signup == .ordinary ? .wizard : .schoolStepOnly
  }

  /// Where an invited parent goes: the school step for the athlete already in the family, else the dashboard.
  /// Nil for the wizard route, which decides its own exit.
  static func invitedParentDestination(
    for route: ParentFirstRun, members: [FamilyMember]
  ) -> ParentOnboardingWizardViewModel.ExitDestination? {
    guard route == .schoolStepOnly else { return nil }
    guard let athlete = FirstRunCopy.connectedAthlete(in: members) else { return .dashboard }
    return .schoolStep(athleteUserId: athlete.userId)
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

  /// Set from the moment a parent finishes signup in this session until their first-run ends. Signup creates the
  /// family itself, so a new parent is already a member and the family rule alone would skip first-run. In memory
  /// only, so a cold launch never brings it back.
  private(set) var parentFirstRun: ParentFirstRun?
  /// The signup signal lives on AuthManager until sign-out; once first-run has ended it must not start it again.
  private var parentSignupConsumed = false

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
      parentFirstRun = OnboardingGate.parentFirstRun(
        role: user.role, flagComplete: complete,
        signup: parentSignupConsumed ? nil : authManager.parentSignupThisSession, latched: parentFirstRun
      )
      needsOnboarding = OnboardingGate.needsOnboarding(
        role: user.role, flagComplete: complete, isInFamily: isInFamily, parentFirstRun: parentFirstRun
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
      // A failed read must neither end a first-run in progress nor skip one that is about to start: a parent
      // who just signed up lands in it, treating the unreadable flag as incomplete.
      parentFirstRun = OnboardingGate.parentFirstRun(
        role: user.role, flagComplete: false,
        signup: parentSignupConsumed ? nil : authManager.parentSignupThisSession, latched: parentFirstRun
      )
      needsOnboarding = parentFirstRun != nil
      needsSportOnly = false
    }
  }

  /// Back to "loading" so the next user is routed by their own status, not the previous user's.
  func reset() {
    session += 1
    needsOnboarding = nil
    needsSportOnly = false
    parentFirstRun = nil
    parentSignupConsumed = false
  }

  /// Ends an invited parent's first-run. The wizard writes `onboarding_complete` itself; the school-step-only
  /// route has no such step, so it is written here (best effort, like the wizard), or web would send the parent
  /// back to /onboarding.
  func finishParentFirstRun() async {
    let finishSession = session
    if parentFirstRun == .schoolStepOnly, let userId = authManager.user?.id {
      do {
        try await onboardingService.completeOnboarding(
          userId: userId,
          assessment: .defaultForOnboarding,
          startingPhase: OnboardingAssessment.startingPhase(for: .defaultForOnboarding, graduationYear: nil)
        )
      } catch {
        logger.error("completeOnboarding failed for invited parent: \(error.localizedDescription)")
      }
    }
    // Signed out (and maybe another user in) while the write was in flight: this must not end their onboarding.
    guard finishSession == session else { return }
    markComplete()
  }

  func markComplete() {
    if parentFirstRun != nil { parentSignupConsumed = true }
    parentFirstRun = nil
    needsOnboarding = false
  }
}
