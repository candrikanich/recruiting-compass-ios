import SwiftUI
import UIKit

/// Onboarding (`skipInviteStep == true`): single player-details step, saved directly, no invite sent — matches web.
/// Dashboard "Invite Athlete" re-entry (`skipInviteStep == false`): 2-step wizard, (1) player details, (2) send invite by email.
struct ParentOnboardingWizardView: View {
  @Bindable var viewModel: ParentOnboardingWizardViewModel
  var onDismiss: (() -> Void)?

  var body: some View {
    NavigationStack {
      ZStack {
        LinearGradient.primaryBackground
          .ignoresSafeArea()

        VStack(spacing: 0) {
          if !viewModel.skipInviteStep {
            stepIndicator
          }
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
      .navigationTitle(viewModel.skipInviteStep ? "Tell us about your player" : "Invite Player")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onDismiss?()
          }
        }
      }
      .toast(
        isShowing: Binding(
          get: { viewModel.showSuccessToast },
          set: { viewModel.showSuccessToast = $0 }
        ),
        message: Binding(
          get: { viewModel.successMessage },
          set: { viewModel.successMessage = $0 }
        ),
        type: .success,
        duration: 2.0
      )
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
    case .sendInvite:
      sendInviteStep
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

  @ViewBuilder
  private var sendInviteStep: some View {
    VStack(alignment: .leading, spacing: FamilyConstants.Spacing.medium) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Welcome to The Recruiting Compass")
          .font(.title2.weight(.semibold))
        Text("Invite your player")
          .font(.headline)
        Text("Send them an email invite or share your family code.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: FamilyConstants.Spacing.small) {
        Text("Player's email address")
          .font(.subheadline.weight(.medium))
        TextField("player@example.com", text: $viewModel.inviteEmail)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .autocapitalization(.none)
          .accessibilityLabel(String(localized: "Player email for invite"))
          .formFieldStyle()
      }

      Button {
        Task { await viewModel.sendInvite() }
      } label: {
        if viewModel.isLoading {
          ProgressView().tint(.white)
        } else {
          Text("Send Invite")
            .font(.callout.weight(.semibold))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: 48)
      .foregroundStyle(.white)
      .background(LinearGradient.primaryButton)
      .clipShape(.rect(cornerRadius: 8))
      .opacity(!viewModel.isInviteStepValid || viewModel.isLoading ? 0.5 : 1)
      .disabled(!viewModel.isInviteStepValid || viewModel.isLoading)
      .accessibilityLabel(String(localized: "Send invite"))

      Text("Or share your family code")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.top, FamilyConstants.Spacing.small)

      if viewModel.isLoadingFamilyCode {
        HStack(spacing: FamilyConstants.Spacing.small) {
          ProgressView()
          Text("Loading family code…")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(FamilyConstants.Spacing.small)
        .background(Color(.tertiarySystemFill))
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Loading family code"))
      } else if let code = viewModel.familyCode {
        VStack(spacing: FamilyConstants.Spacing.small) {
          Text(code)
            .font(.system(.title2, design: .monospaced).weight(.bold))
            .tracking(2)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FamilyConstants.Spacing.medium)
            .background(Color.gray.opacity(0.1))
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityLabel(String(localized: "\(FamilyUtilities.formatCodeForVoiceOver(code))"))
          Button {
            UIPasteboard.general.string = code
          } label: {
            Label("Copy", systemImage: "doc.on.doc")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Copy family code"))
          Text("Your player enters this code during their signup.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } else {
        VStack(alignment: .leading, spacing: FamilyConstants.Spacing.small) {
          Text("Family code couldn't be loaded.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Button("Retry") {
            Task { await viewModel.loadFamilyCode() }
          }
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Retry loading family code"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FamilyConstants.Spacing.small)
        .background(Color(.tertiarySystemFill))
        .clipShape(.rect(cornerRadius: 8))
      }

      Button("I'll invite them later") {
        onDismiss?()
      }
      .buttonStyle(.bordered)
      .frame(maxWidth: .infinity)
      .padding(.top, FamilyConstants.Spacing.small)
      .accessibilityLabel(String(localized: "Skip invite for now"))
    }
    .task(id: viewModel.currentStep) {
      if viewModel.currentStep == .sendInvite {
        await viewModel.loadFamilyCode()
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
          viewModel.nextStep()
        } label: {
          if viewModel.isLoading {
            ProgressView().tint(.white)
              .padding(.horizontal, 24)
              .padding(.vertical, 12)
          } else {
            Text(viewModel.skipInviteStep ? "Get Started" : "Next")
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
        .accessibilityLabel(String(localized: "Next step"))
      }
      // Step 2: primary action (Send Invite) is in sendInviteStep content; only Back in bar
    }
    .padding(FamilyConstants.Spacing.medium)
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
