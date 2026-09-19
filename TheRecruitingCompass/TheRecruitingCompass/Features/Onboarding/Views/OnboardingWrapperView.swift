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
/// The "Skip for now" escape hatch is iOS-only — web's equivalent wizard has no skip button.
private struct ParentOnboardingWrapperContent: View {
  var onComplete: () -> Void
  @Environment(AuthManager.self) private var authManager
  @Environment(OnboardingManager.self) private var onboardingManager
  @State private var viewModel = ParentOnboardingWizardViewModel()

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
