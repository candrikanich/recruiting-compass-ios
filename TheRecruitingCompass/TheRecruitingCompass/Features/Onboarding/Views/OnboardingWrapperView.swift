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

/// Parent onboarding: single player-details step, saved directly — matches production web. Inviting the
/// athlete is deferred to the dashboard's "Invite Athlete" banner. No skip: web's wizard has none, and the
/// family now comes from signup, not from finishing this step.
/// After the details, a parent whose family already has a connected athlete gets the first-run school step
/// ("Which school is your athlete most excited about?"); with no connected athlete they go straight to the
/// dashboard, and no school is written (that path is #492).
private struct ParentOnboardingWrapperContent: View {
  var onComplete: () -> Void
  @Environment(AuthManager.self) private var authManager
  @Environment(OnboardingManager.self) private var onboardingManager
  @State private var viewModel = ParentOnboardingWizardViewModel()
  @State private var schoolViewModel = OnboardingV2ViewModel()
  @State private var showsSchoolStep = false

  var body: some View {
    if showsSchoolStep {
      FirstRunSchoolStepScreen(viewModel: schoolViewModel, onFinish: finish)
    } else {
      ParentOnboardingWizardView(viewModel: viewModel, onDismiss: {
        Task { await wizardDismissed() }
      })
      .environment(authManager)
    }
  }

  private func wizardDismissed() async {
    switch await viewModel.resolveExit() {
    case .schoolStep(let athleteUserId):
      schoolViewModel.recommendationAthleteId = athleteUserId
      showsSchoolStep = true
    case .dashboard:
      finish()
    case nil:
      break
    }
  }

  private func finish() {
    onboardingManager.markComplete()
    onComplete()
  }
}

/// The first-run school step for a parent, on the setup background. Setup is already complete for a parent, so
/// finishing only leaves the screen.
struct FirstRunSchoolStepScreen: View {
  @State private var viewModel: OnboardingV2ViewModel
  var onFinish: () -> Void

  init(viewModel: OnboardingV2ViewModel, onFinish: @escaping () -> Void) {
    _viewModel = State(initialValue: viewModel)
    self.onFinish = onFinish
  }

  init(athleteUserId: String, onFinish: @escaping () -> Void) {
    let viewModel = OnboardingV2ViewModel()
    viewModel.recommendationAthleteId = athleteUserId
    self.init(viewModel: viewModel, onFinish: onFinish)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.Brand.forest600.ignoresSafeArea()
        OnboardingStepTwoView(viewModel: viewModel, completesOnboarding: false, onFinish: onFinish)
          .background(Color.white.opacity(0.95))
          .clipShape(.rect(cornerRadius: 16))
          .colorScheme(.light)
          .padding(24)
      }
    }
  }
}
