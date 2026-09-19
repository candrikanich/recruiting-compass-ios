import SwiftUI

/// Single-step parent onboarding: player details, saved directly, straight to dashboard — matches
/// production web (`pages/onboarding/parent.vue`, single step). Inviting the athlete happens later,
/// from the dashboard's ParentOnboardingBanner (InviteAthleteView), not as a blocking step here.
struct ParentOnboardingWizardView: View {
  @Bindable var viewModel: ParentOnboardingWizardViewModel
  var onDismiss: (() -> Void)?

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient.primaryBackground
          .ignoresSafeArea()

        VStack(spacing: 0) {
          ScrollView {
            playerDetailsStep
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

  @ViewBuilder
  private var navigationButtons: some View {
    HStack {
      Spacer()
      Button {
        Task { await viewModel.finishOnboarding() }
      } label: {
        if viewModel.isLoading {
          ProgressView().tint(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        } else {
          Text("Get Started")
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
      }
      .foregroundStyle(.white)
      .background(LinearGradient.primaryButton)
      .clipShape(.rect(cornerRadius: 8))
      .opacity(viewModel.isPlayerDetailsValid && !viewModel.isLoading ? 1 : 0.5)
      .disabled(!viewModel.isPlayerDetailsValid || viewModel.isLoading)
      .accessibilityLabel(String(localized: "Get started"))
    }
    .padding(FamilyConstants.Spacing.medium)
  }
}

/// Matches LoginFormField's input styling so the wizard reads as part of the signup family.
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
