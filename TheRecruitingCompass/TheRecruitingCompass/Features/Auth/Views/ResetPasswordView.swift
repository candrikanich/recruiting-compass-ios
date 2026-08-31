import SwiftUI

struct ResetPasswordView: View {
  @State private var viewModel: ResetPasswordViewModel
  @State private var showForgotPassword = false
  @Environment(\.dismiss) var dismiss
  @Environment(\.sizeCategory) var sizeCategory
  @Environment(\.horizontalSizeClass) private var sizeClass
  @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 48

  init(authManager: AuthManager? = nil) {
    let manager = authManager ?? .shared
    _viewModel = State(initialValue: ResetPasswordViewModel(authManager: manager))
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
              Text("Back")
                .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Color.darkSlate)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
          }
          .accessibilityLabel(String(localized: "Back to previous screen"))
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)

        ScrollView {
          stateContent
        }
        .navigationDestination(isPresented: $showForgotPassword) {
          ForgotPasswordView()
        }
        .background(Color.white.opacity(0.95))
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: sizeClass == .regular ? 672 : .infinity)
        .padding(24)

        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
    .onChange(of: viewModel.shouldNavigateToLogin) { _, shouldNavigate in
      if shouldNavigate {
        dismiss()
      }
    }
  }

  // MARK: - State Content

  @ViewBuilder
  private var stateContent: some View {
    switch viewModel.state {
    case .form:
      formContent
    case .resetting:
      formContent
    case .success:
      successContent
    case .error(let message):
      errorContent(message: message)
    }
  }

  // MARK: - Form State

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
        Text("Reset Password")
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.darkSlate)

        Text("Enter your new password below.")
          .font(.footnote)
          .foregroundStyle(Color.secondaryText)
      }

      PasswordFormField(
        label: String(localized: "New Password"),
        placeholder: "Enter your new password",
        text: $viewModel.newPassword,
        error: viewModel.errorBinding(for: .newPassword),
        isPasswordVisible: $viewModel.isPasswordVisible,
        onBlur: viewModel.validateNewPassword
      )
      .disabled(viewModel.isLoading)

      PasswordStrengthIndicator(password: viewModel.newPassword)
        .padding(.horizontal, 16)

      PasswordFormField(
        label: String(localized: "Confirm Password"),
        placeholder: "Re-enter your new password",
        text: $viewModel.confirmPassword,
        error: viewModel.errorBinding(for: .confirmPassword),
        isPasswordVisible: $viewModel.isPasswordVisible,
        onBlur: viewModel.validateConfirmPassword
      )
      .disabled(viewModel.isLoading)

      if !viewModel.confirmPassword.isEmpty {
        passwordMatchIndicator
      }

      Button(action: {
        Task {
          await viewModel.resetPassword()
        }
      }) {
        HStack {
          Text(viewModel.isLoading ? String(localized: "Resetting...") : String(localized: "Reset Password"))
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
      .accessibilityLabel(viewModel.isLoading ? String(localized: "Resetting password") : String(localized: "Reset password"))
      .accessibilityHint("Sets your new password")
    }
    .padding(32)
  }

  // MARK: - Password Match Indicator

  @ViewBuilder
  private var passwordMatchIndicator: some View {
    HStack(spacing: 6) {
      Image(systemName: viewModel.passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundStyle(viewModel.passwordsMatch
          ? Color.successGreen
          : Color.errorRed)
        .accessibilityHidden(true)

      Text(viewModel.passwordsMatch ? String(localized: "Passwords match") : String(localized: "Passwords do not match"))
        .font(.caption)
        .foregroundStyle(viewModel.passwordsMatch
          ? Color.successGreen
          : Color.errorRed)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(viewModel.passwordsMatch ? String(localized: "Passwords match") : String(localized: "Passwords do not match"))
  }

  // MARK: - Success State

  @ViewBuilder
  private var successContent: some View {
    VStack(spacing: 24) {
      VerificationStatusIcon(state: .verified)

      VStack(spacing: 8) {
        Text("Password Reset!")
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.darkSlate)

        Text("Your password has been updated successfully.")
          .font(.footnote)
          .foregroundStyle(Color.secondaryText)
          .multilineTextAlignment(.center)
      }

      InfoBanner(state: .verified)

      Text("Redirecting to login in \(viewModel.successCountdown)s...")
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .accessibilityLabel(String(localized: "Redirecting to login in \(viewModel.successCountdown) seconds"))

      Button(action: { dismiss() }) {
        Text("Sign In Now")
          .font(.callout.weight(.semibold))
          .frame(maxWidth: .infinity)
          .frame(minHeight: 48)
          .foregroundStyle(.white)
          .background(
            LinearGradient.primaryButton
          )
          .clipShape(.rect(cornerRadius: 8))
      }
      .accessibilityLabel(String(localized: "Sign in now"))
      .accessibilityHint("Navigate to the login screen")
    }
    .padding(32)
  }

  // MARK: - Error State

  private func errorContent(message: String) -> some View {
    VStack(spacing: 24) {
      VerificationStatusIcon(state: .error(message: message))

      VStack(spacing: 8) {
        Text("Invalid Link")
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.darkSlate)

        Text("This password reset link is no longer valid.")
          .font(.footnote)
          .foregroundStyle(Color.secondaryText)
          .multilineTextAlignment(.center)
      }

      ErrorBanner(
        message: message,
        onDismiss: {}
      )

      Button(action: { showForgotPassword = true }) {
        Text("Request New Link")
          .font(.callout.weight(.semibold))
          .frame(maxWidth: .infinity)
          .frame(minHeight: 48)
          .foregroundStyle(.white)
          .background(
            LinearGradient.primaryButton
          )
          .clipShape(.rect(cornerRadius: 8))
      }
      .accessibilityLabel(String(localized: "Request a new password reset link"))

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
}

#Preview {
  NavigationStack {
    ResetPasswordView()
  }
}
