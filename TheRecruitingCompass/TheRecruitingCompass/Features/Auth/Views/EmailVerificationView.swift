import SwiftUI

struct EmailVerificationView: View {
  @State private var viewModel: EmailVerificationViewModel
  @Environment(\.dismiss) var dismiss
  @Environment(\.scenePhase) var scenePhase

  init(authManager: (any AuthManaging)? = nil) {
    let manager = authManager ?? AuthManager.shared
    _viewModel = State(initialValue: EmailVerificationViewModel(authManager: manager))
  }

  var body: some View {
    ZStack {
      LinearGradient.primaryBackground
        .ignoresSafeArea()

      VStack(spacing: 0) {
        backButton
        contentCard
        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
    .onAppear { viewModel.onAppear() }
    .onDisappear { viewModel.onDisappear() }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active && !viewModel.isVerified {
        viewModel.startPolling()
      } else if newPhase == .background {
        viewModel.stopPolling()
      }
    }
    .onChange(of: viewModel.verificationState) { _, newState in
      if case .verified = newState {
        Task {
          try? await Task.sleep(for: .seconds(0.3))
          UIAccessibility.post(
            notification: .announcement,
            argument: "Email verified! You can now access the app."
          )
        }
      } else if case .error(let message) = newState {
        UIAccessibility.post(
          notification: .announcement,
          argument: "Email verification failed. \(message)"
        )
      }
    }
  }

  // MARK: - Sub-views

  @ViewBuilder
  private var backButton: some View {
    HStack {
      Button(action: { dismiss() }) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.left")
            .font(.footnote.weight(.semibold))
            .accessibilityHidden(true)
          Text("Back to Welcome")
            .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(Color.darkSlate)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "Back to welcome screen"))
      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  @ViewBuilder
  private var contentCard: some View {
    ScrollView {
      VStack(spacing: 24) {
        VerificationStatusIcon(state: viewModel.verificationState)
          .padding(.vertical, 24)

        headerSection

        InfoBanner(state: viewModel.verificationState, email: viewModel.userEmail)

        errorSection

        Spacer()

        actionButton

        cooldownText
      }
      .padding(32)
    }
    .background(Color.white.opacity(0.95))
    .clipShape(.rect(cornerRadius: 16))
    .padding(24)
  }

  @ViewBuilder
  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(viewModel.headlineText)
        .font(.title2.weight(.semibold))
        .foregroundStyle(Color.darkSlate)

      Text(viewModel.subtitleText)
        .font(.footnote)
        .foregroundStyle(Color.secondaryText)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(viewModel.headlineText)
    .accessibilityValue(viewModel.subtitleText)
    .accessibilityAddTraits(.isHeader)
  }

  @ViewBuilder
  private var errorSection: some View {
    if let errorMessage = viewModel.errorMessage {
      ErrorBanner(
        message: errorMessage,
        onDismiss: viewModel.dismissError
      )
      .transition(.opacity)
    }
  }

  @ViewBuilder
  private var actionButton: some View {
    Button(action: {
      if viewModel.isVerified {
        dismiss()
      } else {
        Task { await viewModel.resendVerificationEmail() }
      }
    }) {
      HStack {
        Text(viewModel.actionButtonText)
          .font(.callout.weight(.semibold))

        if viewModel.verificationState == .checking {
          ProgressView()
            .tint(.white)
            .accessibilityLabel(String(localized: "Checking verification"))
        }
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: 48)
      .foregroundStyle(.white)
      .background(LinearGradient.primaryButton)
      .clipShape(.rect(cornerRadius: 8))
      .opacity(viewModel.isButtonDisabled ? 0.5 : 1)
      .disabled(viewModel.isButtonDisabled)
    }
    .accessibilityLabel(viewModel.accessibilityLabelForButton)
    .accessibilityHint(viewModel.accessibilityHintForButton)
  }

  @ViewBuilder
  private var cooldownText: some View {
    if viewModel.shouldShowCooldownText {
      Text("Resend email in \(viewModel.resendCooldownSeconds)s")
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel("Resend available in \(viewModel.resendCooldownSeconds) seconds")
    }
  }
}

#Preview {
  NavigationStack {
    EmailVerificationView()
  }
}
