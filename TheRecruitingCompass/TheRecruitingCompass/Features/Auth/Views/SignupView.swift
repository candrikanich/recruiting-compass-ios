import SwiftUI

struct SignupView: View {
  @StateObject private var viewModel = SignupViewModel()
  @EnvironmentObject var authManager: AuthManager
  @Environment(\.dismiss) var dismiss

  var body: some View {
    ZStack {
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
        HStack {
          Button(action: { dismiss() }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.left")
                .font(.system(size: 14, weight: .semibold))
              Text("Back")
                .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))
          }
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)

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
  }

  // MARK: - Role Selection Step

  private var roleSelectionContent: some View {
    VStack(spacing: 24) {
      Image(systemName: "compass.drawing")
        .font(.system(size: 48))
        .foregroundColor(Color(red: 0.024, green: 0.588, blue: 0.412))
        .padding(.vertical, 12)

      VStack(alignment: .leading, spacing: 12) {
        Text("Select Your Role")
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))

        Text("Choose the account type that best fits your needs")
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))
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
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Button(action: { viewModel.backToRoleSelection() }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.left")
                .font(.system(size: 12, weight: .semibold))
              Text("Change Role")
                .font(.system(size: 12, weight: .regular))
            }
            .foregroundColor(Color(red: 0.149, green: 0.388, blue: 0.931))
          }

          Spacer()

          if let role = viewModel.selectedRole {
            HStack(spacing: 6) {
              Image(systemName: role.icon)
                .font(.system(size: 14))
              Text(role.displayName)
                .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.024, green: 0.588, blue: 0.412))
          }
        }
        .frame(height: 40)
      }

      if let error = viewModel.errorMessage {
        ErrorBanner(
          message: error,
          onDismiss: viewModel.dismissError
        )
        .transition(.opacity)
      }

      LoginFormField(
        label: "Full Name",
        placeholder: "John Doe",
        icon: "person",
        text: $viewModel.fullName,
        error: Binding(
          get: { viewModel.fieldErrors["fullName"] },
          set: { viewModel.fieldErrors["fullName"] = $0 }
        ),
        isSecure: false,
        keyboardType: .default,
        onBlur: viewModel.validateFullName
      )

      LoginFormField(
        label: "Email",
        placeholder: "your.email@example.com",
        icon: "envelope",
        text: $viewModel.email,
        error: Binding(
          get: { viewModel.fieldErrors["email"] },
          set: { viewModel.fieldErrors["email"] = $0 }
        ),
        isSecure: false,
        keyboardType: .emailAddress,
        onBlur: viewModel.validateEmail
      )

      VStack(alignment: .leading, spacing: 4) {
        LoginFormField(
          label: "Password",
          placeholder: "Create a strong password",
          icon: "lock",
          text: $viewModel.password,
          error: Binding(
            get: { viewModel.fieldErrors["password"] },
            set: { viewModel.fieldErrors["password"] = $0 }
          ),
          isSecure: true,
          keyboardType: .default,
          onBlur: viewModel.validatePassword
        )

        PasswordStrengthIndicator(password: viewModel.password)
          .padding(.horizontal, 16)
          .padding(.top, 8)
      }

      LoginFormField(
        label: "Confirm Password",
        placeholder: "Re-enter your password",
        icon: "lock.fill",
        text: $viewModel.confirmPassword,
        error: Binding(
          get: { viewModel.fieldErrors["confirmPassword"] },
          set: { viewModel.fieldErrors["confirmPassword"] = $0 }
        ),
        isSecure: true,
        keyboardType: .default,
        onBlur: viewModel.validateConfirmPassword
      )

      if viewModel.selectedRole?.requiresFamilyCode == true {
        LoginFormField(
          label: "Family Code (Optional)",
          placeholder: "FAM-XXXXXXXX",
          icon: "person.2",
          text: $viewModel.familyCode,
          error: Binding(
            get: { viewModel.fieldErrors["familyCode"] },
            set: { viewModel.fieldErrors["familyCode"] = $0 }
          ),
          isSecure: false,
          keyboardType: .default,
          onBlur: viewModel.validateFamilyCode
        )
      }

      TermsCheckbox(
        isChecked: $viewModel.termsAccepted,
        onTermsPressed: {}
      )

      Button(action: {
        Task {
          await viewModel.signup()
        }
      }) {
        HStack {
          Text(viewModel.isLoading ? "Creating Account..." : "Create Account")
            .font(.system(size: 16, weight: .semibold))

          if viewModel.isLoading {
            ProgressView()
              .tint(.white)
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
        .opacity(viewModel.isButtonDisabled ? 0.5 : 1)
        .disabled(viewModel.isButtonDisabled)
      }

      HStack {
        Text("Already have an account?")
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))

        NavigationLink(value: "login") {
          HStack(spacing: 4) {
            Text("Sign In")
              .font(.system(size: 14, weight: .semibold))
            Image(systemName: "arrow.right")
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundColor(Color(red: 0.149, green: 0.388, blue: 0.931))
        }
      }
    }
    .padding(32)
  }
}

#Preview {
  NavigationStack {
    SignupView()
      .environmentObject(AuthManager.shared)
  }
}
