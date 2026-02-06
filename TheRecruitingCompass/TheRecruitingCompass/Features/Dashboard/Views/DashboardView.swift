import SwiftUI
import Combine

struct DashboardView: View {
  @StateObject private var viewModel: DashboardViewModel
  @EnvironmentObject var authManager: AuthManager

  init(authManager: AuthManager = .shared) {
    _viewModel = StateObject(wrappedValue: DashboardViewModel(authManager: authManager))
  }

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      Image(systemName: "compass.drawing")
        .font(.system(size: 64))
        .foregroundColor(Color(red: 0.024, green: 0.588, blue: 0.412))

      VStack(spacing: 8) {
        Text("Welcome!")
          .font(.system(size: 28, weight: .bold))
          .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))

        Text(viewModel.userEmail)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Session Token (debug)")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(Color(red: 0.627, green: 0.655, blue: 0.686))

        Text(viewModel.truncatedSessionToken)
          .font(.system(size: 12, weight: .regular, design: .monospaced))
          .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(.systemGray6))
          .cornerRadius(8)
      }
      .padding(.horizontal, 32)

      if let errorMessage = viewModel.logoutErrorMessage {
        Text(errorMessage)
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(.red)
          .padding(.horizontal, 32)
      }

      Spacer()

      Button(action: {
        Task {
          await viewModel.logout()
        }
      }) {
        HStack {
          Image(systemName: "rectangle.portrait.and.arrow.right")
          Text(viewModel.isLoggingOut ? "Logging out..." : "Log Out")
            .font(.system(size: 16, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .foregroundColor(.white)
        .background(Color(red: 0.859, green: 0.149, blue: 0.149))
        .cornerRadius(8)
      }
      .disabled(viewModel.isLoggingOut)
      .opacity(viewModel.isLoggingOut ? 0.6 : 1)
      .padding(.horizontal, 32)
      .padding(.bottom, 32)
    }
  }
}

#Preview {
  DashboardView()
    .environmentObject(AuthManager.shared)
}
