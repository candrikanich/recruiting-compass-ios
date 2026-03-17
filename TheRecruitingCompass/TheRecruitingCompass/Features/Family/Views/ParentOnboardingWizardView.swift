import SwiftUI
import UIKit

/// 2-step parent onboarding: (1) Player details, (2) Send invite by email with prefill.
struct ParentOnboardingWizardView: View {
  @Bindable var viewModel: ParentOnboardingWizardViewModel
  var onDismiss: (() -> Void)?

  var body: some View {
    NavigationStack {
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
      .navigationTitle("Invite Player")
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
    .accessibilityLabel("Step \(viewModel.currentStep.rawValue + 1) of \(ParentOnboardingWizardViewModel.Step.allCases.count)")
  }

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
          .textFieldStyle(.roundedBorder)
          .textContentType(.givenName)
          .accessibilityLabel("Athlete first name")

        Text("Player's date of birth")
          .font(.subheadline.weight(.medium))
        DatePicker(
          "mm/dd/yyyy",
          selection: $viewModel.playerDateOfBirth,
          displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .accessibilityLabel("Player date of birth")
        .onChange(of: viewModel.playerDateOfBirth) { _, _ in
          viewModel.onDateOfBirthChange()
        }

        Text("Players must be 13 or older to create an account.")
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
        .accessibilityLabel("Athlete sport")
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
          .accessibilityLabel("Athlete position")
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
        .accessibilityLabel("Athlete graduation year")
      }
    }
  }

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
          .textFieldStyle(.roundedBorder)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .autocapitalization(.none)
          .accessibilityLabel("Player email for invite")
      }

      Button {
        Task { await viewModel.sendInvite() }
      } label: {
        if viewModel.isLoading {
          ProgressView().tint(.white)
        } else {
          Text("Send Invite")
        }
      }
      .frame(maxWidth: .infinity)
      .buttonStyle(.borderedProminent)
      .disabled(!viewModel.isInviteStepValid || viewModel.isLoading)
      .accessibilityLabel("Send invite")

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
        .accessibilityLabel("Loading family code")
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
            .accessibilityLabel(FamilyUtilities.formatCodeForVoiceOver(code))
          Button {
            UIPasteboard.general.string = code
          } label: {
            Label("Copy", systemImage: "doc.on.doc")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel("Copy family code")
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
          .accessibilityLabel("Retry loading family code")
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
      .accessibilityLabel("Skip invite for now")
    }
    .task(id: viewModel.currentStep) {
      if viewModel.currentStep == .sendInvite {
        await viewModel.loadFamilyCode()
      }
    }
  }

  private var navigationButtons: some View {
    HStack(spacing: FamilyConstants.Spacing.medium) {
      if viewModel.currentStep.rawValue > 0 {
        Button("Back") {
          viewModel.previousStep()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Previous step")
      }
      Spacer()
      if viewModel.currentStep == .playerDetails {
        Button("Next") {
          viewModel.nextStep()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.isPlayerDetailsValid)
        .accessibilityLabel("Next step")
      }
      // Step 2: primary action (Send Invite) is in sendInviteStep content; only Back in bar
    }
    .padding(FamilyConstants.Spacing.medium)
  }
}
