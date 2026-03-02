import SwiftUI

/// Wraps onboarding: shows ParentOnboardingWizardView for parents (before dashboard), OnboardingView for players.
struct OnboardingWrapperView: View {
  var onComplete: () -> Void
  @Environment(AuthManager.self) private var authManager
  @Environment(OnboardingManager.self) private var onboardingManager
  @State private var viewModel = OnboardingViewModel()

  var body: some View {
    if authManager.user?.role == .parent {
      ParentOnboardingWrapperContent(onComplete: onComplete)
    } else {
      OnboardingView(viewModel: viewModel, onComplete: {
        onboardingManager.markComplete()
        onComplete()
      })
    }
  }
}

/// Parent onboarding: 2-step wizard (player details → invite) with option to skip, matching web.
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
