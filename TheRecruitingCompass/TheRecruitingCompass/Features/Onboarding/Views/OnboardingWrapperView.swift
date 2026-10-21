import SwiftUI

/// Wraps onboarding: shows ParentOnboardingWizardView for parents (before dashboard), OnboardingView for players.
struct OnboardingWrapperView: View {
  var onComplete: () -> Void
  @Environment(AuthManager.self) private var authManager
  @Environment(OnboardingManager.self) private var onboardingManager

  var body: some View {
    if authManager.user?.role == .parent {
      ParentOnboardingWrapperContent(onComplete: onComplete)
    } else {
      OnboardingContainerView(onComplete: {
        onboardingManager.markComplete()
        onComplete()
      })
    }
  }
}

/// Parent onboarding: single player-details step, saved directly, straight to dashboard — matches
/// production web. Inviting the athlete is deferred to the dashboard's "Invite Athlete" banner.
/// No skip: web's wizard has none, and the family now comes from signup, not from finishing this step.
private struct ParentOnboardingWrapperContent: View {
  var onComplete: () -> Void
  @Environment(AuthManager.self) private var authManager
  @Environment(OnboardingManager.self) private var onboardingManager
  @State private var viewModel = ParentOnboardingWizardViewModel()

  var body: some View {
    ParentOnboardingWizardView(viewModel: viewModel, onDismiss: {
      onboardingManager.markComplete()
      onComplete()
    })
    .environment(authManager)
  }
}
