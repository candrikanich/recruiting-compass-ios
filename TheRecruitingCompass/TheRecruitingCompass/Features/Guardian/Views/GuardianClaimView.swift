import SwiftUI

/// Guardian-facing confirmation screen reached via a `/guardian/claim/:token`
/// link. Mirrors web's `pages/guardian/claim/[token].vue`.
struct GuardianClaimView: View {
  @State var viewModel: GuardianClaimViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch viewModel.state {
          case .loading:
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding(.top, 40)
          case .error(let message):
            Text(message)
              .foregroundStyle(.red)
          case .confirmed:
            confirmedContent
          case .loaded(let details):
            loadedContent(details)
          }
        }
        .padding(24)
      }
      .navigationTitle("Confirm Account")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .task { await viewModel.load() }
    }
  }

  @ViewBuilder
  private var confirmedContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("You're connected!", systemImage: "checkmark.circle.fill")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.green)
      Text("Your athlete's account is confirmed. They now have full access to coach messaging and profile publishing.")
        .foregroundStyle(.secondary)
      Button("Done") { dismiss() }
        .buttonStyle(.borderedProminent)
    }
  }

  @ViewBuilder
  private func loadedContent(_ details: GuardianClaimDetails) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("\(details.playerName) wants you to confirm their Recruiting Compass account.")
        .font(.headline)

      if let errorMessage = viewModel.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      if viewModel.isAuthenticated {
        Button(action: { Task { await viewModel.confirm() } }) {
          if viewModel.isConfirming {
            ProgressView().tint(.white)
          } else {
            Text("Confirm")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isConfirming)
      } else {
        Text("Sign in with \(details.guardianEmail) to confirm.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        LoginFormField(
          label: String(localized: "Email"),
          placeholder: "your.email@example.com",
          icon: "envelope",
          text: $viewModel.loginEmail,
          error: .constant(nil),
          isSecure: false,
          keyboardType: .emailAddress,
          textContentType: .emailAddress,
          onBlur: {}
        )
        LoginFormField(
          label: String(localized: "Password"),
          placeholder: "Password",
          icon: "lock",
          text: $viewModel.loginPassword,
          error: .constant(nil),
          isSecure: true,
          keyboardType: .default,
          textContentType: .password,
          onBlur: {}
        )

        Button(action: { Task { await viewModel.confirm() } }) {
          if viewModel.isConfirming {
            ProgressView().tint(.white)
          } else {
            Text("Sign In & Confirm")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isConfirming || viewModel.loginEmail.isEmpty || viewModel.loginPassword.isEmpty)

        Text("Don't have an account yet? Create one with this same email from the app's sign-in screen, then come back to this link.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
