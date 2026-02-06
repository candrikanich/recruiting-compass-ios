import SwiftUI

struct EmailVerificationView: View {
  @StateObject private var viewModel: EmailVerificationViewModel
  @Environment(\.dismiss) var dismiss
  @Environment(\.scenePhase) var scenePhase

  init(authManager: any AuthManaging = AuthManager.shared) {
    _viewModel = StateObject(wrappedValue: EmailVerificationViewModel(authManager: authManager))
  }

  var body: some View {
    ZStack {
      // Emerald gradient background
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.024, green: 0.588, blue: 0.412),
          Color(red: 0.016, green: 0.522, blue: 0.373)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        // Back button
        HStack {
          Button(action: { dismiss() }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.left")
                .font(.system(size: 14, weight: .semibold))
                .accessibilityHidden(true)
              Text("← Back to Welcome")
                .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))
          }
          .accessibilityLabel("Back to welcome screen")
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)

        ScrollView {
          VStack(spacing: 24) {
            // Status icon
            VerificationStatusIcon(state: viewModel.verificationState)
              .padding(.vertical, 24)

            // Content
            VStack(alignment: .leading, spacing: 12) {
              Text(headlineText)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))

              Text(subtitleText)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(headlineText)
            .accessibilityValue(subtitleText)
            .accessibilityAddTraits(.isHeader)

            // Info banner
            switch viewModel.verificationState {
            case .pending:
              if let email = viewModel.userEmail {
                InfoBanner.pending(email: email)
              }
            case .checking:
              InfoBanner.checking()
            case .verified:
              InfoBanner.verified()
            case .error:
              EmptyView()
            }

            // Error banner
            if let errorMessage = viewModel.errorMessage {
              ErrorBanner(
                message: errorMessage,
                onDismiss: viewModel.dismissError
              )
              .transition(.opacity)
            }

            Spacer()

            // Action button
            Button(action: {
              if viewModel.isVerified {
                dismiss()
              } else {
                Task {
                  await viewModel.resendVerificationEmail()
                }
              }
            }) {
              HStack {
                Text(actionButtonText)
                  .font(.system(size: 16, weight: .semibold))

                if viewModel.verificationState == .checking {
                  ProgressView()
                    .tint(.white)
                    .accessibilityLabel("Checking verification")
                }
              }
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .foregroundColor(.white)
              .background(
                LinearGradient(
                  gradient: Gradient(colors: [
                    Color(red: 0, green: 0.4, blue: 1),
                    Color(red: 0, green: 0.32, blue: 0.8)
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .cornerRadius(8)
              .opacity(isButtonDisabled ? 0.5 : 1)
              .disabled(isButtonDisabled)
            }
            .accessibilityLabel(accessibilityLabelForButton)
            .accessibilityHint(accessibilityHintForButton)

            if !viewModel.canResendEmail && !viewModel.isVerified {
              Text("Resend email in \(viewModel.resendCooldownSeconds)s")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("Resend available in \(viewModel.resendCooldownSeconds) seconds")
            }
          }
          .padding(32)
        }
        .background(Color.white.opacity(0.95))
        .cornerRadius(16)
        .padding(24)

        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
    .onAppear { viewModel.onAppear() }
    .onDisappear { viewModel.onDisappear() }
    .onChange(of: scenePhase) { newPhase in
      if newPhase == .active {
        // Resume when app returns to foreground
        if !viewModel.isVerified && viewModel.verificationState != .verified {
          viewModel.startPolling()
        }
      } else if newPhase == .background {
        // Pause when app goes to background
        viewModel.stopPolling()
      }
    }
  }

  // MARK: - Private Properties

  private var headlineText: String {
    switch viewModel.verificationState {
    case .pending, .checking:
      return "Verify Your Email"
    case .verified:
      return "Verified!"
    case .error:
      return "Verification Issue"
    }
  }

  private var subtitleText: String {
    switch viewModel.verificationState {
    case .pending:
      return "We've sent a verification link to your email. Click it to verify your account."
    case .checking:
      return "Checking your email verification status..."
    case .verified:
      return "Your email has been verified successfully! You can now access the app."
    case .error:
      return "We encountered an issue verifying your email. Please try again."
    }
  }

  private var actionButtonText: String {
    if viewModel.isVerified {
      return "Continue to Dashboard"
    } else if !viewModel.canResendEmail {
      return "Resend Email (Cooldown)"
    } else {
      return "Resend Verification Email"
    }
  }

  private var isButtonDisabled: Bool {
    if viewModel.isVerified {
      return false
    }
    return !viewModel.canResendEmail || viewModel.verificationState == .checking
  }

  private var accessibilityLabelForButton: String {
    if viewModel.isVerified {
      return "Continue to dashboard"
    } else if viewModel.verificationState == .checking {
      return "Checking verification status"
    } else {
      return "Resend verification email"
    }
  }

  private var accessibilityHintForButton: String {
    if viewModel.isVerified {
      return "Navigate to dashboard"
    } else if !viewModel.canResendEmail {
      return "Wait \(viewModel.resendCooldownSeconds) seconds before resending"
    } else {
      return "Send another verification email"
    }
  }
}

#Preview {
  NavigationStack {
    EmailVerificationView()
  }
}
