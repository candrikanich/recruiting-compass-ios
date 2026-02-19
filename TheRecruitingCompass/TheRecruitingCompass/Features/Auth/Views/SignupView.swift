import SwiftUI

struct SignupView: View {
  @State private var viewModel = SignupViewModel()
  @State private var showPrivacyPolicy = false
  @Environment(\.dismiss) var dismiss
  @Environment(\.sizeCategory) var sizeCategory

  var body: some View {
    ZStack {
      LinearGradient.primaryBackground
      .ignoresSafeArea()

      VStack(spacing: 0) {
        backButton

        ScrollView {
          if !viewModel.showForm {
            roleSelectionContent
          } else {
            signupFormContent
          }
        }
        .background(Color.white.opacity(0.95))
        .cornerRadius(16)
        .padding(24)

        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
    .navigationDestination(isPresented: $viewModel.shouldNavigateToVerifyEmail) {
      EmailVerificationView()
    }
    .sheet(isPresented: $showPrivacyPolicy) {
      PrivacyPolicyView()
    }
  }

  // MARK: - Back Button

  private var backButton: some View {
    HStack {
      Button(action: { dismiss() }) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.left")
            .font(.footnote.weight(.semibold))
            .accessibilityHidden(true)
          Text("Back")
            .font(.footnote.weight(.semibold))
        }
        .foregroundColor(Color.darkSlate)
      }
      .accessibilityLabel("Back to welcome screen")
      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  // MARK: - Role Selection Step

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  private var roleSelectionContent: some View {
    VStack(spacing: 24) {
      Image(systemName: "compass.drawing")
        .font(.system(size: iconSize))
        .foregroundColor(Color.primaryGreen)
        .padding(.vertical, 12)
        .scaleEffect(sizeCategory >= .extraLarge ? 1.08 : 1.0)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 12) {
        Text("Select Your Role")
          .font(.title3.weight(.semibold))
          .foregroundColor(Color.darkSlate)

        Text("Choose the account type that best fits your needs")
          .font(.footnote)
          .foregroundColor(Color.secondaryText)
      }

      ForEach(UserRole.allCases, id: \.self) { role in
        RoleSelectionCard(
          role: role,
          isSelected: viewModel.selectedRole == role,
          action: { viewModel.selectRole(role) }
        )
      }
    }
    .padding(32)
  }

  // MARK: - Signup Form Step

  private var signupFormContent: some View {
    VStack(spacing: 24) {
      roleHeader
      errorBannerSection
      fullNameField
      emailField
      passwordSection
      confirmPasswordField
      familyCodeField
      termsSection
      createAccountButton
      signInSection
    }
    .padding(32)
  }

  // MARK: - Form Sub-views

  private var roleHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Button(action: { viewModel.backToRoleSelection() }) {
          HStack(spacing: 4) {
            Image(systemName: "arrow.left")
              .font(.caption.weight(.semibold))
              .accessibilityHidden(true)
            Text("Change Role")
              .font(.caption)
          }
          .foregroundColor(Color.accentBlue)
        }
        .accessibilityLabel("Change role selection")
        .accessibilityHint("Return to role selection screen")

        Spacer()

        if let role = viewModel.selectedRole {
          HStack(spacing: 6) {
            Image(systemName: role.icon)
              .font(.footnote)
              .accessibilityHidden(true)
            Text(role.displayName)
              .font(.footnote.weight(.semibold))
          }
          .foregroundColor(Color.primaryGreen)
        }
      }
      .frame(minHeight: 44)
    }
  }

  @ViewBuilder
  private var errorBannerSection: some View {
    if let error = viewModel.errorMessage {
      ErrorBanner(
        message: error,
        onDismiss: viewModel.dismissError
      )
      .transition(.opacity)
    }
  }

  private var fullNameField: some View {
    LoginFormField(
      label: "Full Name",
      placeholder: "John Doe",
      icon: "person",
      text: $viewModel.fullName,
      error: viewModel.errorBinding(for: .fullName),
      isSecure: false,
      keyboardType: .default,
      onBlur: viewModel.validateFullName
    )
  }

  private var emailField: some View {
    LoginFormField(
      label: "Email",
      placeholder: "your.email@example.com",
      icon: "envelope",
      text: $viewModel.email,
      error: viewModel.errorBinding(for: .email),
      isSecure: false,
      keyboardType: .emailAddress,
      onBlur: viewModel.validateEmail
    )
  }

  private var passwordSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      LoginFormField(
        label: "Password",
        placeholder: "Create a strong password",
        icon: "lock",
        text: $viewModel.password,
        error: viewModel.errorBinding(for: .password),
        isSecure: true,
        keyboardType: .default,
        onBlur: viewModel.validatePassword
      )

      PasswordStrengthIndicator(password: viewModel.password)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
  }

  private var confirmPasswordField: some View {
    LoginFormField(
      label: "Confirm Password",
      placeholder: "Re-enter your password",
      icon: "lock.fill",
      text: $viewModel.confirmPassword,
      error: viewModel.errorBinding(for: .confirmPassword),
      isSecure: true,
      keyboardType: .default,
      onBlur: viewModel.validateConfirmPassword
    )
  }

  @ViewBuilder
  private var familyCodeField: some View {
    if viewModel.selectedRole?.requiresFamilyCode == true {
      LoginFormField(
        label: "Family Code (Optional)",
        placeholder: "FAM-XXXXXXXX",
        icon: "person.2",
        text: $viewModel.familyCode,
        error: viewModel.errorBinding(for: .familyCode),
        isSecure: false,
        keyboardType: .default,
        onBlur: viewModel.validateFamilyCode
      )
    }
  }

  private var termsSection: some View {
    TermsCheckbox(
      isChecked: $viewModel.termsAccepted,
      onTermsPressed: { },
      onPrivacyPressed: { showPrivacyPolicy = true }
    )
  }

  private var createAccountButton: some View {
    Button(action: {
      Task {
        await viewModel.signup()
      }
    }) {
      HStack {
        Text(viewModel.isLoading ? "Creating Account..." : "Create Account")
          .font(.callout.weight(.semibold))

        if viewModel.isLoading {
          ProgressView()
            .tint(.white)
            .accessibilityLabel("Creating account")
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .foregroundColor(.white)
      .background(
        LinearGradient.primaryButton
      )
      .cornerRadius(8)
      .opacity(viewModel.isButtonDisabled ? 0.5 : 1)
      .disabled(viewModel.isButtonDisabled)
    }
    .accessibilityLabel(viewModel.isLoading ? "Creating account, please wait" : "Create account")
    .accessibilityHint("Double tap to create your account")
  }

  private var signInSection: some View {
    HStack {
      Text("Already have an account?")
        .font(.footnote)
        .foregroundColor(Color.tertiaryText)

      NavigationLink(value: "login") {
        HStack(spacing: 4) {
          Text("Sign In")
            .font(.footnote.weight(.semibold))
          Image(systemName: "arrow.right")
            .font(.caption.weight(.semibold))
            .accessibilityHidden(true)
        }
        .foregroundColor(Color.accentBlue)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .accessibilityLabel("Sign in to existing account")
      .accessibilityHint("Navigate to login screen")
    }
  }
}

#Preview {
  NavigationStack {
    SignupView()
  }
  .environment(AuthManager.shared)
}
