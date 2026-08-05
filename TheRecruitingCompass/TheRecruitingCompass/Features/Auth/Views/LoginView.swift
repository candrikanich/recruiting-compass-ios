import SwiftUI

struct LoginView: View {
  private enum ScrollAnchor { case signInButton }

  @State private var viewModel: LoginViewModel
  @State private var showForgotPassword = false
  @State private var showSignup = false
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

        ScrollViewReader { proxy in
          ScrollView {
            VStack(spacing: 20) {
              compassIcon
              bannerSection
              emailField
              passwordField
              rememberMeRow
              signInButton
                .id(LoginView.ScrollAnchor.signInButton)
              VStack(spacing: 0) {
                dividerSection
                signUpSection
              }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 32)
          }
          .scrollDismissesKeyboard(.interactively)
          .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
              proxy.scrollTo(LoginView.ScrollAnchor.signInButton, anchor: .bottom)
            }
          }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(.rect(cornerRadius: 16))
        .padding(24)

        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
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
      }
      .accessibilityLabel(String(localized: "Back to welcome screen"))
      .accessibilityHint("Returns to the login screen")
      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  @ViewBuilder
  private var compassIcon: some View {
    Image("LogoStacked")
      .resizable()
      .scaledToFit()
      .aspectRatio(3.0 / 2.0, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
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

  @ViewBuilder
  private var emailField: some View {
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
  }

  @ViewBuilder
  private var passwordField: some View {
    LoginFormField(
      label: String(localized: "Password"),
      placeholder: "Enter your password",
      icon: "lock",
      text: $viewModel.password,
      error: viewModel.errorBinding(for: .password),
      isSecure: true,
      keyboardType: .default,
      textContentType: .password,
      onBlur: viewModel.validatePassword
    )
    .disabled(viewModel.isLoading)
    .onSubmit {
      Task {
        await viewModel.login()
      }
    }
  }

  @ViewBuilder
  private var rememberMeRow: some View {
    HStack(spacing: 12) {
      Button(action: { viewModel.rememberMe.toggle() }) {
        HStack(spacing: 6) {
          Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
            .foregroundStyle(Color.accentBlue)
            .accessibilityHidden(true)

          Text("Remember me")
            .font(.footnote)
            .foregroundStyle(Color.primary)
        }
        .frame(minHeight: 44)
      }
      .accessibilityLabel(String(localized: "Remember me"))
      .accessibilityValue(viewModel.rememberMe ? "checked" : "unchecked")
      .accessibilityHint("Check to save your email for next login")

      Spacer()

      Button(action: { showForgotPassword = true }) {
        Text("Forgot password?")
          .font(.footnote)
          .foregroundStyle(Color.primary)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "Forgot password"))
      .accessibilityHint("Opens password recovery screen")
      .navigationDestination(isPresented: $showForgotPassword) {
        ForgotPasswordView()
      }
    }
  }

  @ViewBuilder
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
      .frame(minHeight: 48)
      .foregroundStyle(.white)
      .background(LinearGradient.primaryButton)
      .clipShape(.rect(cornerRadius: 8))
      .opacity(viewModel.isButtonDisabled ? 0.5 : 1)
      .disabled(viewModel.isButtonDisabled)
    }
    .accessibilityLabel(viewModel.isLoading ? String(localized: "Signing in") : String(localized: "Sign in to account"))
    .accessibilityHint(viewModel.isLoading ? "Please wait while we verify your credentials" : "Sign in with your email and password")
  }

  @ViewBuilder
  private var dividerSection: some View {
    Rectangle()
      .frame(height: 1)
      .foregroundStyle(Color(uiColor: .separator))
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var signUpSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("New to The Recruiting Compass?")
        .padding(.top, 12)
        .font(.footnote)
        .foregroundStyle(Color.secondary)

      HStack(spacing: 4) {
        Text("Don't have an account?")
          .font(.footnote)
          .foregroundStyle(Color.secondary)

        Button(action: { showSignup = true }) {
          HStack(spacing: 4) {
            Text("Create one now")
              .font(.footnote.weight(.semibold))
            Image(systemName: "arrow.right")
              .font(.caption.weight(.semibold))
              .accessibilityHidden(true)
          }
          .foregroundStyle(Color.accentBlue)
          .frame(minHeight: 44)
          .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Create account"))
        .accessibilityHint("Opens the account creation form")
        .navigationDestination(isPresented: $showSignup) {
          SignupView()
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    LoginView()
  }
  .environment(AuthManager.shared)
}
