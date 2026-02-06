import SwiftUI

struct LoginView: View {
  @StateObject private var viewModel = LoginViewModel()
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
              Text("Back to Welcome")
                .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))
          }
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)

        ScrollView {
          VStack(spacing: 24) {
            Image(systemName: "compass.drawing")
              .font(.system(size: 48))
              .foregroundColor(Color(red: 0.024, green: 0.588, blue: 0.412))
              .padding(.vertical, 12)

            if viewModel.showTimeoutBanner {
              TimeoutBanner()
                .transition(.opacity)
            }

            if let error = viewModel.errorMessage {
              ErrorBanner(
                message: error,
                onDismiss: viewModel.dismissError
              )
              .transition(.opacity)
            }

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

            LoginFormField(
              label: "Password",
              placeholder: "Enter your password",
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

            HStack(spacing: 12) {
              HStack(spacing: 6) {
                Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
                  .foregroundColor(Color(red: 0.149, green: 0.388, blue: 0.931))
                  .onTapGesture {
                    viewModel.rememberMe.toggle()
                  }

                Text("Remember me")
                  .font(.system(size: 14, weight: .regular))
                  .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))
                  .onTapGesture {
                    viewModel.rememberMe.toggle()
                  }
              }
              .frame(height: 44)

              Spacer()

              NavigationLink(value: "forgot-password") {
                Text("Forgot password?")
                  .font(.system(size: 14, weight: .regular))
                  .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))
              }
            }

            Button(action: {
              Task {
                await viewModel.login()
              }
            }) {
              HStack {
                Text(viewModel.isLoading ? "Signing in..." : "Sign In")
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
              Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(red: 0.827, green: 0.843, blue: 0.863))

              Text("New to Recruiting Compass?")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))

              Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(red: 0.827, green: 0.843, blue: 0.863))
            }

            HStack(spacing: 4) {
              Text("Don't have an account?")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(red: 0.282, green: 0.337, blue: 0.431))

              NavigationLink(value: "signup") {
                HStack(spacing: 4) {
                  Text("Create one now")
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
        .background(Color.white.opacity(0.95))
        .cornerRadius(16)
        .padding(24)

        Spacer()
      }
    }
    .navigationBarBackButtonHidden(true)
  }
}

#Preview {
  NavigationStack {
    LoginView()
      .environmentObject(AuthManager.shared)
  }
}
