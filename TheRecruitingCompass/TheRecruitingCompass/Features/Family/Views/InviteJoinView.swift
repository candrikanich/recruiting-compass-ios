import SwiftUI

struct InviteJoinView: View {
  @State var viewModel: InviteJoinViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        switch viewModel.state {
        case .loading:
          loadingView
        case .error(let err):
          errorView(err)
        case .declined:
          declinedView
        case .loaded(let invite):
          inviteView(invite)
        }
      }
      .navigationTitle("Join Family")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
    .task { await viewModel.loadInvite() }
    .onChange(of: viewModel.navigateToDashboard) { _, navigates in
      if navigates { dismiss() }
    }
    .toast(
      isShowing: Binding(
        get: { viewModel.showSuccessToast },
        set: { viewModel.showSuccessToast = $0 }
      ),
      message: Binding(
        get: { viewModel.successMessage },
        set: { viewModel.successMessage = $0 }
      ),
      type: .success,
      duration: 2.0
    )
  }

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Loading invite...")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func errorView(_ error: InviteError) -> some View {
    VStack(spacing: 16) {
      Image(systemName: iconForError(error))
        .font(.system(size: 48))
        .foregroundStyle(colorForError(error))
        .accessibilityHidden(true)

      Text(titleForError(error))
        .font(.title3.weight(.semibold))
        .multilineTextAlignment(.center)

      Text(error.errorDescription ?? "")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)

      if error == .alreadyAccepted {
        Button("Go to Dashboard") { dismiss() }
          .buttonStyle(.borderedProminent)
          .padding(.top, 8)
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var declinedView: some View {
    VStack(spacing: 16) {
      Image(systemName: "hand.raised")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("Invitation declined")
        .font(.title3.weight(.semibold))
        .multilineTextAlignment(.center)

      Text("You've declined this invitation. No action is needed.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)

      Button("Close") { dismiss() }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func iconForError(_ error: InviteError) -> String {
    switch error {
    case .expired: return "clock.badge.xmark"
    case .alreadyAccepted: return "checkmark.circle"
    case .notFound: return "link.badge.plus"
    case .serverError: return "exclamationmark.triangle"
    }
  }

  private func colorForError(_ error: InviteError) -> Color {
    switch error {
    case .alreadyAccepted: return .green
    default: return .orange
    }
  }

  private func titleForError(_ error: InviteError) -> String {
    switch error {
    case .expired: return "This invite has expired"
    case .alreadyAccepted: return "Already connected"
    case .notFound: return "Invite not found"
    case .serverError: return "Something went wrong"
    }
  }

  @ViewBuilder
  private func inviteView(_ invite: InviteDetails) -> some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Text("You're invited to join")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("\(invite.familyName)'s recruiting journey")
            .font(.title2.weight(.bold))
            .multilineTextAlignment(.center)
          Text("\(invite.inviterName) invited you as a \(invite.role).")
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 16)

        if let error = viewModel.errorMessage {
          Text(error)
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        if viewModel.isAuthenticated {
          authenticatedConnectSection(invite: invite)
        } else if invite.emailExists {
          unauthenticatedLoginSection(invite: invite)
        } else {
          unauthenticatedSignupSection(invite: invite)
        }
      }
      .padding(24)
    }
  }

  private func authenticatedConnectSection(invite: InviteDetails) -> some View {
    VStack(spacing: 12) {
      Button {
        Task { await viewModel.accept() }
      } label: {
        Group {
          if viewModel.isAccepting {
            ProgressView().tint(.white)
          } else {
            Text("Connect to \(invite.familyName)")
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
      }
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isAccepting)

      declineButton(loading: viewModel.isDeclining)
    }
  }

  private func unauthenticatedLoginSection(invite: InviteDetails) -> some View {
    VStack(spacing: 16) {
      Text("Log in to connect your account.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(spacing: 12) {
        TextField("Email", text: $viewModel.loginEmail)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .autocapitalization(.none)
          .disabled(true)

        SecureField("Password", text: $viewModel.loginPassword)
          .textFieldStyle(.roundedBorder)
          .textContentType(.password)
      }

      Button {
        Task { await viewModel.accept() }
      } label: {
        Group {
          if viewModel.isAccepting {
            ProgressView().tint(.white)
          } else {
            Text("Log in and connect")
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
      }
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isAccepting)

      declineButton(loading: viewModel.isDeclining)
    }
  }

  private func unauthenticatedSignupSection(invite: InviteDetails) -> some View {
    VStack(spacing: 16) {
      Text("Create an account to connect.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let err = viewModel.signupError {
        Text(err)
          .font(.subheadline)
          .foregroundStyle(.red)
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.red.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }

      VStack(spacing: 12) {
        HStack(spacing: 12) {
          TextField("First name", text: $viewModel.signupFirstName)
            .textFieldStyle(.roundedBorder)
            .textContentType(.givenName)
          TextField("Last name", text: $viewModel.signupLastName)
            .textFieldStyle(.roundedBorder)
            .textContentType(.familyName)
        }

        Text(invite.email)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        if invite.role == "player" {
          VStack(alignment: .leading, spacing: 4) {
            Text("Date of Birth")
              .font(.caption)
              .foregroundStyle(.secondary)
            DatePicker(
              "Date of Birth",
              selection: $viewModel.signupDateOfBirth,
              in: ...Date(),
              displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
          }
        }

        SecureField("Password", text: $viewModel.signupPassword)
          .textFieldStyle(.roundedBorder)
          .textContentType(.newPassword)

        SecureField("Confirm password", text: $viewModel.signupConfirmPassword)
          .textFieldStyle(.roundedBorder)
          .textContentType(.newPassword)

        Toggle(isOn: $viewModel.signupAgreeToTerms) {
          Text("I agree to the Terms and Privacy Policy")
            .font(.caption)
        }
      }

      Button {
        Task { await viewModel.signupAndConnect() }
      } label: {
        Group {
          if viewModel.isAccepting {
            ProgressView().tint(.white)
          } else {
            Text("Create account and connect")
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
      }
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isAccepting)

      declineButton(loading: viewModel.isDeclining)
    }
  }

  private func declineButton(loading: Bool) -> some View {
    Button(role: .destructive) {
      Task { await viewModel.decline() }
    } label: {
      Group {
        if loading {
          ProgressView().tint(.red)
        } else {
          Text("Decline invitation")
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 44)
    }
    .buttonStyle(.bordered)
    .tint(.red)
    .disabled(loading)
  }
}
