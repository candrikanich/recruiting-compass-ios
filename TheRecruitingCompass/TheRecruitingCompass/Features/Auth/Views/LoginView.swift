import SwiftUI
import Combine

struct LoginView: View {
  @State private var viewModel: LoginViewModel
  @Environment(\.dismiss) var dismiss
  @Environment(\.sizeCategory) var sizeCategory

  init(timeoutReason: String? = nil) {
    _viewModel = State(initialValue: LoginViewModel(timeoutReason: timeoutReason))
  }

  var body: some View {
    ZStack {
      LinearGradient.primaryBackground
      .ignoresSafeArea()

      VStack(spacing: 0) {
        backButton

        ScrollView {
          VStack(spacing: 24) {
            compassIcon
            bannerSection
            emailField
            passwordField
            rememberMeRow
            signInButton
            dividerSection
            signUpSection
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
  }

  // MARK: - Sub-views

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
        .foregroundColor(Color.darkSlate)
      }
      .accessibilityLabel("Back to welcome screen")
      .accessibilityHint("Returns to the login screen")
      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  private var compassIcon: some View {
    Image(systemName: "compass.drawing")
      .font(.system(size: iconSize))
      .foregroundColor(Color.primaryGreen)
      .padding(.vertical, 12)
      .scaleEffect(sizeCategory >= .extraLarge ? 1.08 : 1.0)
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var bannerSection: some View {
    if viewModel.showTimeoutBanner {
      TimeoutBanner()
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    if let error = viewModel.errorMessage {
      ErrorBanner(
        message: error,
        onDismiss: viewModel.dismissError
      )
      .transition(.opacity)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
    }
  }

  private var emailField: some View {
    LoginFormField(
      label: "Email",
      placeholder: "your.email@example.com",
      icon: "envelope",
      text: $viewModel.email,
      error: Binding(
        get: { viewModel.fieldErrors[.email] },
        set: { viewModel.fieldErrors[.email] = $0 }
      ),
      isSecure: false,
      keyboardType: .emailAddress,
      onBlur: viewModel.validateEmail
    )
    .disabled(viewModel.isLoading)
  }

  private var passwordField: some View {
    LoginFormField(
      label: "Password",
      placeholder: "Enter your password",
      icon: "lock",
      text: $viewModel.password,
      error: Binding(
        get: { viewModel.fieldErrors[.password] },
        set: { viewModel.fieldErrors[.password] = $0 }
      ),
      isSecure: true,
      keyboardType: .default,
      onBlur: viewModel.validatePassword
    )
    .disabled(viewModel.isLoading)
    .onSubmit {
      Task {
        await viewModel.login()
      }
    }
  }

  private var rememberMeRow: some View {
    HStack(spacing: 12) {
      Button(action: { viewModel.rememberMe.toggle() }) {
        HStack(spacing: 6) {
          Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
            .foregroundColor(Color.accentBlue)
            .accessibilityHidden(true)

          Text("Remember me")
            .font(.footnote)
            .foregroundColor(Color.tertiaryText)
        }
        .frame(height: 44)
      }
      .accessibilityLabel("Remember me")
      .accessibilityValue(viewModel.rememberMe ? "checked" : "unchecked")
      .accessibilityHint("Check to save your email for next login")

      Spacer()

      NavigationLink(destination: ForgotPasswordView()) {
        Text("Forgot password?")
          .font(.footnote)
          .foregroundColor(Color.tertiaryText)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Forgot password")
      .accessibilityHint("Opens password recovery screen")
    }
  }

  private var signInButton: some View {
    Button(action: {
      Task {
        await viewModel.login()
      }
    }) {
      HStack {
        Text(viewModel.isLoading ? "Signing in..." : "Sign In")
          .font(.callout.weight(.semibold))

        if viewModel.isLoading {
          ProgressView()
            .tint(.white)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .foregroundColor(.white)
      .background(LinearGradient.primaryButton)
      .cornerRadius(8)
      .opacity(viewModel.isButtonDisabled ? 0.5 : 1)
      .disabled(viewModel.isButtonDisabled)
    }
    .accessibilityLabel(viewModel.isLoading ? "Signing in" : "Sign in to account")
    .accessibilityHint(viewModel.isLoading ? "Please wait while we verify your credentials" : "Sign in with your email and password")
  }

  private var dividerSection: some View {
    HStack {
      Rectangle()
        .frame(height: 1)
        .foregroundColor(Color.borderGray)
        .accessibilityHidden(true)

      Text("New to Recruiting Compass?")
        .font(.footnote)
        .foregroundColor(Color.tertiaryText)

      Rectangle()
        .frame(height: 1)
        .foregroundColor(Color.borderGray)
        .accessibilityHidden(true)
    }
  }

  private var signUpSection: some View {
    HStack(spacing: 4) {
      Text("Don't have an account?")
        .font(.footnote)
        .foregroundColor(Color.tertiaryText)

      NavigationLink(value: "signup") {
        HStack(spacing: 4) {
          Text("Create one now")
            .font(.footnote.weight(.semibold))
          Image(systemName: "arrow.right")
            .font(.caption.weight(.semibold))
            .accessibilityHidden(true)
        }
        .foregroundColor(Color.accentBlue)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .accessibilityLabel("Create account")
      .accessibilityHint("Opens the account creation form")
    }
  }
}

#Preview {
  NavigationStack {
    LoginView()
  }
  .environment(AuthManager.shared)
}
