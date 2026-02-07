import SwiftUI
import Combine

struct DashboardView: View {
  @StateObject private var viewModel: DashboardViewModel
  @EnvironmentObject var authManager: AuthManager
  @Environment(\.sizeCategory) var sizeCategory

  init(authManager: AuthManager = .shared) {
    _viewModel = StateObject(wrappedValue: DashboardViewModel(authManager: authManager))
  }

  private var compassSize: CGFloat {
    sizeCategory >= .extraLarge ? 70 : 64
  }

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      Image(systemName: "compass.drawing")
        .font(.system(size: compassSize))
        .foregroundColor(Color.primaryGreen)

      VStack(spacing: 8) {
        Text("Welcome!")
          .font(.title)
          .foregroundColor(Color.darkSlate)

        Text(viewModel.userEmail)
          .font(.callout)
          .foregroundColor(Color.secondaryText)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Session Token (debug)")
          .font(.caption.weight(.semibold))
          .foregroundColor(Color.iconGray)

        Text(viewModel.truncatedSessionToken)
          .font(.system(size: 12, weight: .regular, design: .monospaced))
          .foregroundColor(Color.secondaryText)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color(.systemGray6))
          .cornerRadius(8)
      }
      .padding(.horizontal, 32)

      if let errorMessage = viewModel.logoutErrorMessage {
        Text(errorMessage)
          .font(.footnote)
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
            .font(.callout.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .foregroundColor(.white)
        .background(Color.errorRed)
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
