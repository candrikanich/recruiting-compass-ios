import SwiftUI

/// 2-step parent onboarding: (1) Player details, (2) Send invite by email with prefill.
struct ParentOnboardingWizardView: View {
  @Bindable var viewModel: ParentOnboardingWizardViewModel
  var onDismiss: (() -> Void)?

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        stepIndicator
        ScrollView {
          Group {
            switch viewModel.currentStep {
            case .playerDetails:
              playerDetailsStep
            case .sendInvite:
              sendInviteStep
            }
          }
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
      .navigationTitle("Invite Athlete")
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

  private var stepIndicator: some View {
    HStack(spacing: 8) {
      ForEach(ParentOnboardingWizardViewModel.Step.allCases, id: \.rawValue) { step in
        Capsule()
          .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color(.tertiarySystemFill))
          .frame(height: 4)
      }
    }
    .padding(.horizontal, FamilyConstants.Spacing.medium)
    .padding(.vertical, FamilyConstants.Spacing.small)
    .accessibilityLabel("Step \(viewModel.currentStep.rawValue + 1) of \(ParentOnboardingWizardViewModel.Step.allCases.count)")
  }

  private var playerDetailsStep: some View {
    VStack(alignment: .leading, spacing: FamilyConstants.Spacing.medium) {
      Text("Enter your athlete's details")
        .font(.headline)
      Text("We'll include these in the invite so they can prefill their profile.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: FamilyConstants.Spacing.small) {
        Text("First name")
          .font(.subheadline.weight(.medium))
        TextField("First name", text: $viewModel.playerFirstName)
          .textFieldStyle(.roundedBorder)
          .textContentType(.givenName)
          .accessibilityLabel("Athlete first name")

        Text("Last name")
          .font(.subheadline.weight(.medium))
        TextField("Last name", text: $viewModel.playerLastName)
          .textFieldStyle(.roundedBorder)
          .textContentType(.familyName)
          .accessibilityLabel("Athlete last name")

        Text("Sport (optional)")
          .font(.subheadline.weight(.medium))
        Picker("Sport", selection: $viewModel.playerSport) {
          Text("Select sport").tag("")
          ForEach(viewModel.sports, id: \.self) { sport in
            Text(sport).tag(sport)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Athlete sport")

        Text("Position (optional)")
          .font(.subheadline.weight(.medium))
        Picker("Position", selection: $viewModel.playerPosition) {
          Text("Select position").tag("")
          ForEach(viewModel.positions, id: \.self) { pos in
            Text(pos).tag(pos)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Athlete position")

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
      Text("Send invite")
        .font(.headline)
      Text("Enter the email address where your athlete will receive the invite. Invites expire after 30 days.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: FamilyConstants.Spacing.small) {
        Text("Email address")
          .font(.subheadline.weight(.medium))
        TextField("athlete@example.com", text: $viewModel.inviteEmail)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .autocapitalization(.none)
          .accessibilityLabel("Athlete email for invite")
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
      } else {
        Button {
          Task { await viewModel.sendInvite() }
        } label: {
          if viewModel.isLoading {
            ProgressView().tint(.white)
          } else {
            Text("Send invite")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.isInviteStepValid || viewModel.isLoading)
        .accessibilityLabel("Send invite")
      }
    }
    .padding(FamilyConstants.Spacing.medium)
  }
}
