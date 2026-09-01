import SwiftUI

/// Legacy 5-step onboarding flow. Superseded by OnboardingContainerView (2-step v2).
/// Kept for reference during the transition period.
struct OnboardingViewLegacy: View {
  @State private var viewModel: OnboardingViewModel
  @Environment(AuthManager.self) private var authManager

  init(onComplete: @escaping () -> Void) {
    _viewModel = State(initialValue: OnboardingViewModel(onComplete: onComplete))
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.94, green: 0.96, blue: 1), Color(red: 0.88, green: 0.9, blue: 1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        OnboardingHeaderView(authManager: authManager)
        OnboardingProgressBar(currentStep: viewModel.currentStep)
        ScrollView {
          OnboardingScreenContent(viewModel: viewModel)
            .padding()
        }
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)

        if viewModel.errorMessage != nil {
          OnboardingErrorBanner(viewModel: viewModel)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }

        OnboardingNavigationButtons(viewModel: viewModel)
          .padding(.horizontal, 24)
          .padding(.bottom, 24)
      }
      .padding(.top, 24)

      if viewModel.isLoading {
        Color.black.opacity(0.3)
          .ignoresSafeArea()
        ProgressView()
          .scaleEffect(1.5)
          .tint(.white)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("onboardingView")
    .task { await viewModel.loadExistingData() }
  }

}

// MARK: - Extracted subviews

private struct OnboardingHeaderView: View {
  let authManager: AuthManager

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Spacer()
        Button("Sign out") {
          Task {
            try? await authManager.logout()
          }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 24)

      Text("Welcome to The Recruiting Compass")
        .font(.title.weight(.bold))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
      Text("Let's get you set up in just a few steps")
        .font(.body)
        .foregroundStyle(.secondary)

      if let user = authManager.user {
        accountInfoView(user: user)
      }

      Text("Please complete setup to use the app.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 16)
  }

  @ViewBuilder
  private func accountInfoView(user: User) -> some View {
    let displayName = [user.fullName, user.email]
      .compactMap { $0 }
      .joined(separator: " · ")
    if !displayName.isEmpty {
      Text(displayName)
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .padding(.top, 4)
        .accessibilityLabel(String(localized: "Signed in as \(displayName)"))
    }
  }
}

private struct OnboardingProgressBar: View {
  let currentStep: Int

  var body: some View {
    HStack(spacing: 12) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color(uiColor: .tertiarySystemFill))
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor)
            .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(OnboardingConstants.totalSteps))
        }
      }
      .frame(height: 8)

      Text("\(currentStep)/\(OnboardingConstants.totalSteps)")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 24)
  }
}

private struct OnboardingBasicInfoStep: View {
  @Bindable var viewModel: OnboardingViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Basic Information")
        .font(.title2.weight(.bold))

      VStack(alignment: .leading, spacing: 8) {
        Text("Expected Graduation Year *")
          .font(.subheadline.weight(.medium))
        Picker("Graduation year", selection: $viewModel.graduationYearDisplay) {
          Text("Select graduation year").tag("")
          ForEach(OnboardingConstants.graduationYears, id: \.self) { year in
            Text(String(year)).tag(String(year))
          }
        }
        .pickerStyle(.menu)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Primary Sport *")
          .font(.subheadline.weight(.medium))
        Picker("Sport", selection: $viewModel.primarySport) {
          Text("Select your sport").tag("")
          ForEach(OnboardingConstants.commonSports, id: \.self) { sport in
            Text(sport).tag(sport)
          }
        }
        .pickerStyle(.menu)
        .onChange(of: viewModel.primarySport) { _, _ in
          viewModel.onSportChange()
        }
        if let sportError = viewModel.sportError {
          Text(sportError)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      if !viewModel.primarySport.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Primary Position *")
            .font(.subheadline.weight(.medium))
          Picker("Position", selection: $viewModel.primaryPosition) {
            Text("Select position").tag("")
            ForEach(viewModel.positionsForSport, id: \.self) { pos in
              Text(pos).tag(pos)
            }
          }
          .pickerStyle(.menu)
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Gender (optional)")
          .font(.subheadline.weight(.medium))
        Picker("Gender", selection: Binding(
          get: { viewModel.gender ?? "" },
          set: { viewModel.gender = $0.isEmpty ? nil : $0 }
        )) {
          Text(String(localized: "Select")).tag("")
          ForEach(Gender.allCases, id: \.rawValue) { g in
            Text(g.displayName).tag(g.rawValue)
          }
        }
        .pickerStyle(.menu)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 24)
  }
}

private struct OnboardingScreenContent: View {
  @Bindable var viewModel: OnboardingViewModel

  var body: some View {
    switch viewModel.currentStep {
    case 1:
      OnboardingWelcomeStep()
    case 2:
      OnboardingBasicInfoStep(viewModel: viewModel)
    case 3:
      OnboardingLocationStep(viewModel: viewModel)
    case 4:
      OnboardingAcademicStep(viewModel: viewModel)
    case 5:
      OnboardingCompleteStep(viewModel: viewModel)
    default:
      OnboardingWelcomeStep()
    }
  }
}

private struct OnboardingWelcomeStep: View {
  var body: some View {
    VStack(spacing: 24) {
      Text("Welcome!")
        .font(.title2.weight(.bold))
      Text("This onboarding will help us understand your recruiting goals and preferences. It should take about 5 minutes.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 32)
  }
}

private struct OnboardingLocationStep: View {
  @Bindable var viewModel: OnboardingViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Your Location")
        .font(.title2.weight(.bold))
      Text("Tell us your zip code so we can find nearby schools.")
        .font(.body)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 8) {
        Text("Zip Code *")
          .font(.subheadline.weight(.medium))
        TextField("Enter your 5-digit zip code", text: $viewModel.zipCode)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.numberPad)
          .textContentType(.postalCode)
        if let zipError = viewModel.zipCodeError {
          Text(zipError)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 24)
  }
}

private struct OnboardingAcademicStep: View {
  @Bindable var viewModel: OnboardingViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Academic Info")
        .font(.title2.weight(.bold))
      Text("Share your GPA and test scores (optional) for better recommendations.")
        .font(.body)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 8) {
        Text("GPA (Optional)")
          .font(.subheadline.weight(.medium))
        TextField("e.g., 3.8", value: $viewModel.gpa, format: .number)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.decimalPad)
        Text("Scale of 0.0 - 4.0")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("SAT Score (Optional)")
          .font(.subheadline.weight(.medium))
        TextField("e.g., 1500", value: $viewModel.satScore, format: .number)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.numberPad)
        Text("Score between 400-1600")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("ACT Score (Optional)")
          .font(.subheadline.weight(.medium))
        TextField("e.g., 35", value: $viewModel.actScore, format: .number)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.numberPad)
        Text("Score between 1-36")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 24)
  }
}

private struct OnboardingCompleteStep: View {
  @Bindable var viewModel: OnboardingViewModel

  var body: some View {
    VStack(spacing: 24) {
      Text("You're All Set!")
        .font(.title2.weight(.bold))

      Text("Invite a parent or guardian to follow your recruiting journey.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      if viewModel.isInviteSent {
        Label("Invite sent!", systemImage: "checkmark.circle")
          .foregroundStyle(.green)
          .font(.subheadline.weight(.medium))
      } else {
        VStack(spacing: 12) {
          TextField("Parent's email", text: $viewModel.inviteEmail)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .autocapitalization(.none)

          Button {
            Task { await viewModel.sendParentInvite() }
          } label: {
            if viewModel.isLoading {
              ProgressView().tint(.white)
            } else {
              Text("Send Invite")
            }
          }
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(viewModel.isEmailInviteValid ? Color.accentColor : Color.gray)
          .foregroundStyle(.white)
          .clipShape(.rect(cornerRadius: 8))
          .disabled(!viewModel.isEmailInviteValid || viewModel.isLoading)
        }
      }

      Text("You can invite a parent later from Family Management.")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 32)
  }
}

private struct OnboardingErrorBanner: View {
  @Bindable var viewModel: OnboardingViewModel

  var body: some View {
    if let error = viewModel.errorMessage {
      VStack(alignment: .leading, spacing: 8) {
        Text(error)
          .font(.subheadline)
          .foregroundStyle(.red)
        Button("Dismiss") {
          viewModel.clearError()
        }
        .font(.caption)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.red.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct OnboardingNavigationButtons: View {
  @Bindable var viewModel: OnboardingViewModel

  var body: some View {
    HStack {
      Button("Back") {
        viewModel.previousScreen()
      }
      .disabled(viewModel.currentStep == 1 || viewModel.isLoading)
      .foregroundStyle(.secondary)

      Spacer()

      // Step 2 (primary sport) is required, so Skip is hidden there.
      if viewModel.currentStep < OnboardingConstants.totalSteps, viewModel.currentStep != 2 {
        Button("Skip") {
          Task { await viewModel.skipStep() }
        }
        .foregroundStyle(.secondary)
        .padding(.trailing, 8)
      }

      let nextLabel = viewModel.currentStep == OnboardingConstants.totalSteps ? "Complete Onboarding"
        : viewModel.currentStep == 4 ? "Review" : "Next"
      Button(nextLabel) {
        Task { await viewModel.nextScreen() }
      }
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isLoading || (viewModel.currentStep == 2 && !viewModel.isSportStepValid))
    }
  }
}

#Preview {
  OnboardingWrapperView(onComplete: {})
}
