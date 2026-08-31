import SwiftUI

struct SignupView: View {
  @State private var viewModel = SignupViewModel()
  @State private var presentedLegal: LegalDocument?
  @State private var navigateToLogin = false
  @Environment(\.dismiss) var dismiss
  @Environment(\.horizontalSizeClass) private var sizeClass

  var body: some View {
    ZStack {
      LinearGradient.primaryBackground
      .ignoresSafeArea()

      VStack(spacing: 0) {
        SignupBackButtonView(onBack: { dismiss() })

        ScrollView {
          if !viewModel.showForm {
            SignupRoleSelectionView(viewModel: viewModel)
          } else {
            SignupFormView(
              viewModel: viewModel,
              presentedLegal: $presentedLegal,
              onSignIn: { navigateToLogin = true }
            )
          }
        }
        // Disable immediate dismissal during UI testing so typeText can deliver
        // all characters before the indicator layout change causes a micro-scroll.
        .scrollDismissesKeyboard(
          ProcessInfo.processInfo.arguments.contains("--uitesting") ? .never : .immediately
        )
        .background(Color.white.opacity(0.95))
        .clipShape(.rect(cornerRadius: 16))
        .frame(maxWidth: sizeClass == .regular ? 672 : .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)

        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
    .sheet(isPresented: $viewModel.shouldNavigateToVerifyEmail) {
      NavigationStack {
        EmailVerificationView()
      }
    }
    .sheet(item: $presentedLegal) { doc in
      doc.view
    }
    .navigationDestination(isPresented: $navigateToLogin) {
      LoginView()
    }
  }
}

// MARK: - Back Button

private struct SignupBackButtonView: View {
  let onBack: () -> Void

  var body: some View {
    HStack {
      Button(action: onBack) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.left")
            .font(.footnote.weight(.semibold))
            .accessibilityHidden(true)
          Text("Back")
            .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(Color.darkSlate)
      }
      .accessibilityLabel(String(localized: "Back to welcome screen"))
      Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }
}

// MARK: - Role Selection Step

private struct SignupRoleSelectionView: View {
  @Bindable var viewModel: SignupViewModel
  @Environment(\.sizeCategory) var sizeCategory

  var body: some View {
    VStack(spacing: 24) {
      Image("LogoStacked")
        .resizable()
        .scaledToFit()
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .scaleEffect(sizeCategory >= .extraLarge ? 1.08 : 1.0)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 12) {
        Text("Select Your Role")
          .font(.title3.weight(.semibold))
          .foregroundStyle(Color.darkSlate)

        Text("Choose the account type that best fits your needs")
          .font(.footnote)
          .foregroundStyle(Color.secondaryText)
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
}

// MARK: - Signup Form Step

private struct SignupFormView: View {
  @Bindable var viewModel: SignupViewModel
  @Binding var presentedLegal: LegalDocument?
  let onSignIn: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      SignupRoleHeaderView(viewModel: viewModel)
      SignupErrorBannerView(viewModel: viewModel)
      SignupFirstNameFieldView(viewModel: viewModel)
      SignupLastNameFieldView(viewModel: viewModel)
      SignupEmailFieldView(viewModel: viewModel)
      if viewModel.selectedRole == .player {
        SignupDateOfBirthFieldView(viewModel: viewModel)
      }
      SignupPasswordSectionView(viewModel: viewModel)
      SignupConfirmPasswordFieldView(viewModel: viewModel)
      SignupFamilyCodeFieldView(viewModel: viewModel)
      SignupTermsSectionView(viewModel: viewModel, presentedLegal: $presentedLegal)
      SignupCreateAccountButtonView(viewModel: viewModel)
      SignupSignInSectionView(onSignIn: onSignIn)
    }
    .padding(32)
  }
}

// MARK: - Form Sub-views

private struct SignupRoleHeaderView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
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
          .foregroundStyle(Color.accentBlue)
        }
        .accessibilityLabel(String(localized: "Change role selection"))
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
          .foregroundStyle(Color.primaryGreen)
        }
      }
      .frame(minHeight: 44)
    }
  }
}

private struct SignupErrorBannerView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
    if let error = viewModel.errorMessage {
      ErrorBanner(
        message: error,
        onDismiss: viewModel.dismissError
      )
      .transition(.opacity)
    }
  }
}

private struct SignupFirstNameFieldView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
    LoginFormField(
      label: String(localized: "First Name"),
      placeholder: "John",
      icon: "person",
      text: $viewModel.firstName,
      error: viewModel.errorBinding(for: .firstName),
      isSecure: false,
      keyboardType: .default,
      textContentType: .givenName,
      onBlur: viewModel.validateFirstName
    )
  }
}

private struct SignupLastNameFieldView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
    LoginFormField(
      label: String(localized: "Last Name"),
      placeholder: "Smith",
      icon: "person",
      text: $viewModel.lastName,
      error: viewModel.errorBinding(for: .lastName),
      isSecure: false,
      keyboardType: .default,
      textContentType: .familyName,
      onBlur: viewModel.validateLastName
    )
  }
}

private struct SignupDateOfBirthFieldView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "calendar")
          .foregroundStyle(Color.darkSlate)
          .accessibilityHidden(true)
        Text("Date of Birth")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.darkSlate)
      }

      DatePicker(
        "Date of Birth",
        selection: $viewModel.dateOfBirth,
        in: ...Date.now,
        displayedComponents: .date
      )
      .datePickerStyle(.compact)
      .labelsHidden()
      .onChange(of: viewModel.dateOfBirth) { _, _ in
        viewModel.validateDateOfBirth()
      }

      Text("Recruiting Compass is for ages 13 and up. By entering a date of birth, you confirm you are 13 or older.")
        .font(.caption)
        .foregroundStyle(Color.secondary)

      if let error = viewModel.fieldErrors[.dateOfBirth] {
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
      }

      if viewModel.minorRequiresGuardian {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "person.2.fill")
            .foregroundStyle(.orange)
          Text(
            "Players under 18 join through a parent or guardian. Ask your parent to create the account and invite you to their family unit."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}

private struct SignupEmailFieldView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
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
  }
}

private struct SignupPasswordSectionView: View {
  @Bindable var viewModel: SignupViewModel

  // Suppress iOS "Use Strong Password?" sheet during UI testing.
  // Setting textContentType: nil doesn't help — iOS infers .newPassword from two
  // adjacent SecureFields. .oneTimeCode overrides the inference and disables the
  // sheet so XCUITest's typeText can deliver all characters uninterrupted.
  private var passwordTextContentType: UITextContentType? {
    ProcessInfo.processInfo.arguments.contains("--uitesting") ? .oneTimeCode : .newPassword
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      LoginFormField(
        label: String(localized: "Password"),
        placeholder: "Create a strong password",
        icon: "lock",
        text: $viewModel.password,
        error: viewModel.errorBinding(for: .password),
        isSecure: true,
        keyboardType: .default,
        textContentType: passwordTextContentType,
        onBlur: viewModel.validatePassword
      )

      PasswordStrengthIndicator(password: viewModel.password)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
  }
}

private struct SignupConfirmPasswordFieldView: View {
  @Bindable var viewModel: SignupViewModel

  private var passwordTextContentType: UITextContentType? {
    ProcessInfo.processInfo.arguments.contains("--uitesting") ? .oneTimeCode : .newPassword
  }

  var body: some View {
    LoginFormField(
      label: String(localized: "Confirm Password"),
      placeholder: "Re-enter your password",
      icon: "lock.fill",
      text: $viewModel.confirmPassword,
      error: viewModel.errorBinding(for: .confirmPassword),
      isSecure: true,
      keyboardType: .default,
      textContentType: passwordTextContentType,
      onBlur: viewModel.validateConfirmPassword
    )
  }
}

private struct SignupFamilyCodeFieldView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
    if viewModel.selectedRole?.requiresFamilyCode == true {
      LoginFormField(
        label: String(localized: "Family Code (Optional)"),
        placeholder: "FAM-XXXXXX",
        icon: "person.2",
        text: $viewModel.familyCode,
        error: viewModel.errorBinding(for: .familyCode),
        isSecure: false,
        keyboardType: .default,
        onBlur: viewModel.validateFamilyCode
      )
    }
  }
}

private struct SignupTermsSectionView: View {
  @Bindable var viewModel: SignupViewModel
  @Binding var presentedLegal: LegalDocument?

  var body: some View {
    TermsCheckbox(
      isChecked: $viewModel.termsAccepted,
      onTermsPressed: { presentedLegal = .termsOfService },
      onPrivacyPressed: { presentedLegal = .privacyPolicy }
    )
  }
}

private struct SignupCreateAccountButtonView: View {
  @Bindable var viewModel: SignupViewModel

  var body: some View {
    Button(action: {
      Task {
        await viewModel.signup()
      }
    }) {
      HStack {
        Text(viewModel.isLoading ? String(localized: "Creating Account...") : String(localized: "Create Account"))
          .font(.callout.weight(.semibold))

        if viewModel.isLoading {
          ProgressView()
            .tint(.white)
            .accessibilityLabel(String(localized: "Creating account"))
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
    .accessibilityLabel(viewModel.isLoading ? String(localized: "Creating account, please wait") : String(localized: "Create account"))
    .accessibilityHint("Double tap to create your account")
  }
}

private struct SignupSignInSectionView: View {
  let onSignIn: () -> Void

  var body: some View {
    HStack {
      Text("Already have an account?")
        .font(.footnote)
        .foregroundStyle(Color.tertiaryText)

      Button(action: onSignIn) {
        HStack(spacing: 4) {
          Text("Sign In")
            .font(.footnote.weight(.semibold))
          Image(systemName: "arrow.right")
            .font(.caption.weight(.semibold))
            .accessibilityHidden(true)
        }
        .foregroundStyle(Color.accentBlue)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "Sign in to existing account"))
      .accessibilityHint("Navigate to login screen")
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    SignupView()
  }
  .environment(AuthManager.shared)
}
