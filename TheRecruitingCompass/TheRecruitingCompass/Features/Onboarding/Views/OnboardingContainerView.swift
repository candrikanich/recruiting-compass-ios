import SwiftUI

/// Player onboarding container — one step for a player who already supplied sport +
/// graduation year at signup (parity with web's guardian-optional signup wizard, which
/// captures the same fields up front — see planning/iOS_SPEC_web-ios-parity-pass-
/// 2026-09-17.md Item A), two steps otherwise.
///
/// Step 1: "Tell Us About You" — sport, graduation year, zip code. Skipped when
/// `AccountProvisioningService.flushPendingOnboardingStep1()` (called on every
/// authenticated session) already landed this data in canonical preferences.
/// Step 2: "Schools to Explore" — recommendation carousel + push priming. Always shown.
struct OnboardingContainerView: View {
  enum Step { case tellAboutYou, schoolsToExplore }

  @State private var currentStep: Step?
  // True only when this player actually needs both steps (no valid signup-time data).
  // A player who skips straight to schoolsToExplore sees a single screen, not a
  // "Step 2 of 2" indicator implying a wizard they never saw the first half of.
  @State private var showsTwoSteps = false
  // True when the initial preferences fetch itself failed (not merely found nothing) —
  // must block the step decision and offer retry, not silently default to tellAboutYou.
  // See OnboardingV2ViewModel.loadExistingData()'s doc comment.
  @State private var loadFailed = false
  @State private var viewModel = OnboardingV2ViewModel()
  @Environment(AuthManager.self) private var authManager

  var onComplete: (() -> Void)?

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient(
          colors: [Color(red: 0.94, green: 0.96, blue: 1), Color(red: 0.88, green: 0.9, blue: 1)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 0) {
          signOutHeader

          if loadFailed {
            loadFailedView
          } else if let currentStep {
            if showsTwoSteps {
              progressIndicator(currentStep)
            }
            stepContent(currentStep)
          } else {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      }
      .overlay {
        if viewModel.isLoading && currentStep == .tellAboutYou {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
          ProgressView()
            .scaleEffect(1.5)
            .tint(.white)
        }
      }
    }
    .task {
      OnboardingAnalytics.onboardingStarted()
      await resolveInitialStep()
    }
  }

  /// Fetches existing preferences and decides the starting step. On a failed fetch
  /// (network/server error, not merely "nothing saved"), blocks on a retry screen
  /// instead of defaulting to tellAboutYou — see loadExistingData()'s doc comment for
  /// why silently treating a failure as "no data" is unsafe here.
  private func resolveInitialStep() async {
    loadFailed = false
    let loaded = await viewModel.loadExistingData()
    guard loaded else {
      loadFailed = true
      return
    }
    showsTwoSteps = !viewModel.isStep1Valid
    currentStep = viewModel.isStep1Valid ? .schoolsToExplore : .tellAboutYou
  }

  @ViewBuilder private var loadFailedView: some View {
    Spacer()
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("Couldn't load your info")
        .font(.headline)
      Text("Check your connection and try again.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button("Try Again") {
        Task { await resolveInitialStep() }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal, 32)
    Spacer()
  }

  // MARK: - Sign Out

  @ViewBuilder private var signOutHeader: some View {
    HStack {
      Spacer()
      Button("Sign out") {
        Task { try? await authManager.logout() }
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24)
    .padding(.top, 12)
  }

  // MARK: - Progress

  @ViewBuilder
  private func progressIndicator(_ step: Step) -> some View {
    HStack(spacing: 12) {
      stepDot(active: true)
      stepConnector(step)
      stepDot(active: step == .schoolsToExplore)

      Spacer()

      Text(step == .tellAboutYou ? "Step 1 of 2" : "Step 2 of 2")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  private func stepDot(active: Bool) -> some View {
    Circle()
      .fill(active ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
      .frame(width: 10, height: 10)
  }

  private func stepConnector(_ step: Step) -> some View {
    Rectangle()
      .fill(step == .schoolsToExplore ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
      .frame(width: 40, height: 2)
  }

  // MARK: - Step Content

  @ViewBuilder
  private func stepContent(_ step: Step) -> some View {
    switch step {
    case .tellAboutYou:
      OnboardingStepOneView(
        viewModel: viewModel,
        onContinue: {
          withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .schoolsToExplore
          }
        }
      )
    case .schoolsToExplore:
      OnboardingStepTwoView(
        viewModel: viewModel,
        onFinish: {
          onComplete?()
        }
      )
    }
  }
}
