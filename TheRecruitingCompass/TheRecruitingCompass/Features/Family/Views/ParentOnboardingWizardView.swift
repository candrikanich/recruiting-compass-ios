import SwiftUI

/// 2-step parent onboarding: (1) Player details, (2) Schools to explore — matches web's
/// `pages/onboarding/parent.vue`. Inviting the athlete happens later, from the dashboard's
/// ParentOnboardingBanner (InviteAthleteView), not as a blocking step in this wizard.
struct ParentOnboardingWizardView: View {
  @Bindable var viewModel: ParentOnboardingWizardViewModel
  var onDismiss: (() -> Void)?

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient.primaryBackground
          .ignoresSafeArea()

        VStack(spacing: 0) {
          stepIndicator
          ScrollView {
            currentStepContent
              .padding(FamilyConstants.Spacing.medium)
          }
          if let error = viewModel.errorMessage {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
              .padding(.horizontal)
              .padding(.bottom, 8)
          }
          navigationButtons
        }
        .background(Color.white.opacity(0.95))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
      }
      .navigationTitle("Welcome")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onDismiss?()
          }
        }
      }
      .onChange(of: viewModel.didComplete) { _, completed in
        if completed {
          onDismiss?()
        }
      }
    }
  }

  @ViewBuilder
  private var currentStepContent: some View {
    switch viewModel.currentStep {
    case .playerDetails:
      playerDetailsStep
    case .schoolsToExplore:
      schoolsToExploreStep
    }
  }

  @ViewBuilder
  private var stepIndicator: some View {
    HStack(spacing: 8) {
      ForEach(ParentOnboardingWizardViewModel.Step.allCases, id: \.rawValue) { step in
        Capsule()
          .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color(.tertiarySystemFill))
          .frame(height: 4)
      }
      Text("\(viewModel.currentStep.rawValue + 1) of \(ParentOnboardingWizardViewModel.Step.allCases.count)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, FamilyConstants.Spacing.medium)
    .padding(.vertical, FamilyConstants.Spacing.small)
    .accessibilityLabel(String(localized: "Step \(viewModel.currentStep.rawValue + 1) of \(ParentOnboardingWizardViewModel.Step.allCases.count)"))
  }

  @ViewBuilder
  private var playerDetailsStep: some View {
    VStack(alignment: .leading, spacing: FamilyConstants.Spacing.medium) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Welcome to The Recruiting Compass")
          .font(.title2.weight(.semibold))
        Text("Tell us about your player")
          .font(.headline)
        Text("We'll pre-fill their profile so they can hit the ground running. Name, sport, and graduation year are optional.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: FamilyConstants.Spacing.small) {
        Text("Player's first name")
          .font(.subheadline.weight(.medium))
        TextField("First name", text: $viewModel.playerFirstName)
          .textContentType(.givenName)
          .accessibilityLabel(String(localized: "Athlete first name"))
          .formFieldStyle()

        Text("Player's date of birth")
          .font(.subheadline.weight(.medium))
        DatePicker(
          "mm/dd/yyyy",
          selection: $viewModel.playerDateOfBirth,
          displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .accessibilityLabel(String(localized: "Player date of birth"))
        .onChange(of: viewModel.playerDateOfBirth) { _, _ in
          viewModel.onDateOfBirthChange()
        }

        Text("Recruiting Compass is for ages 13 and up. By entering a date of birth, you confirm the player is 13 or older.")
          .font(.caption)
          .foregroundStyle(
            viewModel.hasConfirmedDateOfBirth && viewModel.isPlayerUnderAge
              ? Color.red
              : Color.secondary
          )

        Text("Primary sport (optional)")
          .font(.subheadline.weight(.medium))
        Picker("Sport", selection: $viewModel.playerSport) {
          Text("Select sport").tag("")
          ForEach(viewModel.sports, id: \.self) { sport in
            Text(sport).tag(sport)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: "Athlete sport"))
        .onChange(of: viewModel.playerSport) { _, _ in
          viewModel.onSportChange()
        }

        if !viewModel.playerSport.isEmpty {
          Text("Position (optional)")
            .font(.subheadline.weight(.medium))
          Picker("Position", selection: $viewModel.playerPosition) {
            Text("Select position").tag("")
            ForEach(viewModel.positionsForSport, id: \.self) { pos in
              Text(pos).tag(pos)
            }
          }
          .pickerStyle(.menu)
          .accessibilityLabel(String(localized: "Athlete position"))
        }

        Text("Graduation year (optional)")
          .font(.subheadline.weight(.medium))
        Picker("Graduation year", selection: Binding(
          get: { viewModel.playerGraduationYear.map { String($0) } ?? "" },
          set: { viewModel.playerGraduationYear = Int($0) }
        )) {
          Text("Select year").tag("")
          ForEach(viewModel.graduationYears, id: \.self) { year in
            Text(String(year)).tag(String(year))
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: "Athlete graduation year"))
      }
    }
  }

  /// Matches web's Step 2 "Schools to explore" carousel (`OnboardingStepTwoView`'s player
  /// equivalent) — no invite fields here; inviting the athlete is the dashboard banner's job.
  @ViewBuilder
  private var schoolsToExploreStep: some View {
    VStack(alignment: .leading, spacing: FamilyConstants.Spacing.medium) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Schools to explore")
          .font(.title2.weight(.semibold))
        Text("Based on what you told us, here are a few schools to start with.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if viewModel.isLoadingRecommendations {
        HStack(spacing: FamilyConstants.Spacing.small) {
          ProgressView()
          Text("Finding schools…")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
      } else if viewModel.recommendations.isEmpty {
        Text("Continue to your dashboard to start adding schools manually.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 16)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 16) {
            ForEach(viewModel.recommendations) { rec in
              ParentRecommendationCard(
                recommendation: rec,
                onAdd: { Task { _ = await viewModel.addSchool(rec) } },
                onDismiss: { Task { await viewModel.dismissRecommendation(rec) } }
              )
            }
          }
        }
        .scrollClipDisabled()
      }

      if viewModel.schoolsAdded > 0 {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text("\(viewModel.schoolsAdded) school\(viewModel.schoolsAdded == 1 ? "" : "s") added")
            .font(.subheadline.weight(.medium))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }

      Button {
        viewModel.finishOnboarding()
      } label: {
        Text("Go to your dashboard →")
          .font(.callout.weight(.semibold))
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: 48)
      .foregroundStyle(.white)
      .background(LinearGradient.primaryButton)
      .clipShape(.rect(cornerRadius: 8))
      .accessibilityLabel(String(localized: "Go to your dashboard"))
    }
    .task(id: viewModel.currentStep) {
      if viewModel.currentStep == .schoolsToExplore, viewModel.recommendations.isEmpty {
        await viewModel.loadRecommendations()
      }
    }
  }

  @ViewBuilder
  private var navigationButtons: some View {
    HStack(spacing: FamilyConstants.Spacing.medium) {
      if viewModel.currentStep.rawValue > 0 {
        Button("Back") {
          viewModel.previousStep()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "Previous step"))
      }
      Spacer()
      if viewModel.currentStep == .playerDetails {
        Button {
          Task { await viewModel.proceedFromPlayerDetails() }
        } label: {
          if viewModel.isLoading {
            ProgressView().tint(.white)
          } else {
            Text("Next")
              .font(.callout.weight(.semibold))
              .padding(.horizontal, 24)
              .padding(.vertical, 12)
          }
        }
        .foregroundStyle(.white)
        .background(LinearGradient.primaryButton)
        .clipShape(.rect(cornerRadius: 8))
        .opacity(viewModel.isPlayerDetailsValid ? 1 : 0.5)
        .disabled(!viewModel.isPlayerDetailsValid || viewModel.isLoading)
        .accessibilityLabel(String(localized: "Next step"))
      }
      // Step 2: primary action (Go to Dashboard) is in schoolsToExploreStep content; only Back in bar
    }
    .padding(FamilyConstants.Spacing.medium)
  }
}

/// One recommended school in the parent onboarding wizard's Step 2 carousel.
private struct ParentRecommendationCard: View {
  let recommendation: SchoolRecommendation
  let onAdd: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(recommendation.name)
        .font(.headline)
        .lineLimit(2)

      HStack(spacing: 8) {
        if let division = recommendation.division, !division.isEmpty {
          Text(division)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
        }
        if let state = recommendation.state, !state.isEmpty {
          Text(state)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      HStack(spacing: 12) {
        Button(action: onAdd) {
          Label("Add", systemImage: "plus")
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)

        Button(action: onDismiss) {
          Text("Not a fit")
            .font(.subheadline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(16)
    .frame(width: 240)
    .frame(minHeight: 160)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
  }
}

/// Matches LoginFormField's input styling so the invite wizard reads as part of the signup family.
private extension View {
  func formFieldStyle() -> some View {
    padding(12)
      .background(Color(uiColor: .secondarySystemBackground))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(uiColor: .separator), lineWidth: 1)
      )
      .clipShape(.rect(cornerRadius: 8))
  }
}
