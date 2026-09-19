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

/// Parent onboarding: single player-details step, saved directly (no invite sent) — matches web,
/// which defers inviting the athlete to the dashboard's "Invite Athlete" banner.
private struct ParentOnboardingWrapperContent: View {
  var onComplete: () -> Void
  @Environment(AuthManager.self) private var authManager
  @Environment(OnboardingManager.self) private var onboardingManager
  @State private var viewModel = ParentOnboardingWizardViewModel(skipInviteStep: true)

  var body: some View {
    ParentOnboardingWizardView(viewModel: viewModel, onDismiss: {
      onboardingManager.markParentOnboardingComplete()
      onComplete()
    })
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Skip for now") {
          onboardingManager.markParentOnboardingComplete()
          onComplete()
        }
      }
    }
    .environment(authManager)
  }
}
