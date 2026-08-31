import SwiftUI

struct ForgotPasswordView: View {
  @State private var viewModel: ForgotPasswordViewModel
  @Environment(\.dismiss) var dismiss
  @Environment(\.sizeCategory) var sizeCategory
  @Environment(\.horizontalSizeClass) private var sizeClass

  init(authManager: AuthManager? = nil) {
    let manager = authManager ?? .shared
    _viewModel = State(initialValue: ForgotPasswordViewModel(authManager: manager))
  }

  var body: some View {
    ZStack {
      LinearGradient.primaryBackground
      .ignoresSafeArea()

      VStack(spacing: 0) {
        HStack {
          Button(action: { dismiss() }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.left")
                .font(.footnote.weight(.semibold))
                .accessibilityHidden(true)
              Text("Back to Login")
                .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Color.darkSlate)
          }
          .accessibilityLabel(String(localized: "Back to login screen"))
          .accessibilityHint("Returns to the sign in screen")
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)

        ScrollView {
          if viewModel.emailSent {
            successContent
          } else {
            formContent
          }
        }
        .background(Color.white.opacity(0.95))
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: sizeClass == .regular ? 672 : .infinity)
        .padding(24)

        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
  }

  // MARK: - Form State

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  @ViewBuilder
  private var formContent: some View {
    VStack(spacing: 24) {
      Image(systemName: "lock.rotation")
        .font(.system(size: iconSize))
        .foregroundStyle(Color.primaryGreen)
        .padding(.vertical, 12)
        .scaleEffect(sizeCategory >= .extraLarge ? 1.08 : 1.0)
        .accessibilityHidden(true)

      VStack(spacing: 8) {
        Text("Forgot Password?")
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.darkSlate)

        Text("Enter your email and we'll send you a link to reset your password.")
          .font(.footnote)
          .foregroundStyle(Color.secondaryText)
          .multilineTextAlignment(.center)
      }

      if let error = viewModel.errorMessage {
        ErrorBanner(
          message: error,
          onDismiss: viewModel.dismissError
        )
        .transition(.opacity)
      }

      LoginFormField(
        label: String(localized: "Email"),
        placeholder: "your.email@example.com",
        icon: "envelope",
        text: $viewModel.email,
        error: viewModel.errorBinding(for: .email),
        isSecure: false,
        keyboardType: .emailAddress,
        textContentType: .emailAddress,
        onBlur: viewModel.validateEmail
      )
      .disabled(viewModel.isLoading)

      Button(action: {
        Task {
          await viewModel.sendResetLink()
        }
      }) {
        HStack {
          Text(viewModel.isLoading ? String(localized: "Sending...") : String(localized: "Send Reset Link"))
            .font(.callout.weight(.semibold))

          if viewModel.isLoading {
            ProgressView()
              .tint(.white)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .foregroundStyle(.white)
        .background(
          LinearGradient.primaryButton
        )
        .clipShape(.rect(cornerRadius: 8))
        .opacity(viewModel.isButtonDisabled ? 0.5 : 1)
        .disabled(viewModel.isButtonDisabled)
      }
      .accessibilityLabel(viewModel.isLoading ? String(localized: "Sending reset link") : String(localized: "Send password reset link"))
      .accessibilityHint("Sends a password reset email to your address")
    }
    .padding(32)
  }

  // MARK: - Success State

  @ViewBuilder
  private var successContent: some View {
    VStack(spacing: 24) {
      VerificationStatusIcon(state: .verified)

      VStack(spacing: 8) {
        Text("Check Your Email")
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.darkSlate)
          .accessibilityIdentifier("ForgotPasswordCheckEmailHeading")

        Text("We've sent a password reset link to:")
          .font(.footnote)
          .foregroundStyle(Color.secondaryText)

        Text(viewModel.submittedEmail)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Color.darkSlate)
      }

      if let error = viewModel.errorMessage {
        ErrorBanner(
          message: error,
          onDismiss: viewModel.dismissError
        )
        .transition(.opacity)
      }

      InfoBanner(state: .pending, email: viewModel.submittedEmail)

      Button(action: {
        Task {
          await viewModel.resendResetLink()
        }
      }) {
        HStack {
          if viewModel.isLoading {
            ProgressView()
              .tint(Color.accentBlue)
          }
          Text(resendButtonText)
            .font(.callout.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .foregroundStyle(Color.accentBlue)
        .background(Color.clear)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.accentBlue, lineWidth: 1.5)
        )
        .opacity(viewModel.canResendEmail ? 1 : 0.5)
      }
      .disabled(!viewModel.canResendEmail || viewModel.isLoading)
      .accessibilityLabel(resendButtonAccessibilityLabel)

      Button(action: { viewModel.resetForm() }) {
        Text("Use Different Email")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Color.accentBlue)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "Use a different email address"))
      .accessibilityHint("Returns to the email form")

      Button(action: { dismiss() }) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.left")
            .font(.caption.weight(.semibold))
            .accessibilityHidden(true)
          Text("Back to Login")
            .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(Color.tertiaryText)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "Back to login screen"))
    }
    .padding(32)
  }

  private var resendButtonText: String {
    if !viewModel.canResendEmail {
      return String(localized: "Send Another (\(viewModel.resendCooldownSeconds)s)")
    }
    return String(localized: "Send Another")
  }

  private var resendButtonAccessibilityLabel: String {
    if !viewModel.canResendEmail {
      return String(localized: "Send another reset link, available in \(viewModel.resendCooldownSeconds) seconds")
    }
    return String(localized: "Send another reset link")
  }
}

#Preview {
  NavigationStack {
    ForgotPasswordView()
  }
}
