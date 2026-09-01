import SwiftUI

/// Two-step player onboarding container. Replaces the legacy 5-step `OnboardingView`.
///
/// Step 1: "Tell Us About You" — sport, graduation year, zip code
/// Step 2: "Schools to Explore" — recommendation carousel + push priming
struct OnboardingContainerView: View {
  enum Step { case tellAboutYou, schoolsToExplore }

  @State private var currentStep: Step = .tellAboutYou
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

          progressIndicator

          stepContent
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
    .task { OnboardingAnalytics.onboardingStarted() }
  }

  // MARK: - Sign Out

  private var signOutHeader: some View {
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

  private var progressIndicator: some View {
    HStack(spacing: 12) {
      stepDot(active: true)
      stepConnector
      stepDot(active: currentStep == .schoolsToExplore)

      Spacer()

      Text(currentStep == .tellAboutYou ? "Step 1 of 2" : "Step 2 of 2")
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

  private var stepConnector: some View {
    Rectangle()
      .fill(currentStep == .schoolsToExplore ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
      .frame(width: 40, height: 2)
  }

  // MARK: - Step Content

  @ViewBuilder
  private var stepContent: some View {
    switch currentStep {
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
