import SwiftUI

struct InviteJoinView: View {
  @State var viewModel: InviteJoinViewModel
  @State private var presentedLegal: LegalDocument?
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
    .sheet(item: $presentedLegal) { $0.view }
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
          ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
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
      gradientButton(
        label: "Connect to \(invite.familyName)",
        isLoading: viewModel.isAccepting
      ) {
        Task { await viewModel.accept() }
      }

      declineButton(loading: viewModel.isDeclining)
    }
  }

  private func unauthenticatedLoginSection(invite: InviteDetails) -> some View {
    VStack(spacing: 16) {
      Text("Log in to connect your account.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(spacing: 12) {
        LoginFormField(
          label: "Email",
          placeholder: invite.email,
          icon: "envelope",
          text: .constant(invite.email),
          error: .constant(nil),
          isSecure: false,
          keyboardType: .emailAddress,
          textContentType: .emailAddress,
          onBlur: {}
        )
        .disabled(true)

        LoginFormField(
          label: "Password",
          placeholder: "Your password",
          icon: "lock",
          text: $viewModel.loginPassword,
          error: .constant(nil),
          isSecure: true,
          keyboardType: .default,
          textContentType: .password,
          onBlur: {}
        )
      }

      gradientButton(
        label: "Log in and connect",
        isLoading: viewModel.isAccepting
      ) {
        Task { await viewModel.accept() }
      }

      declineButton(loading: viewModel.isDeclining)
    }
  }

  private func unauthenticatedSignupSection(invite: InviteDetails) -> some View {
    VStack(spacing: 16) {
      Text("Create an account to connect.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let err = viewModel.signupError {
        ErrorBanner(message: err, onDismiss: { viewModel.signupError = nil })
      }

      VStack(spacing: 12) {
        LoginFormField(
          label: "First Name",
          placeholder: "John",
          icon: "person",
          text: $viewModel.signupFirstName,
          error: .constant(nil),
          isSecure: false,
          keyboardType: .default,
          textContentType: .givenName,
          onBlur: {}
        )

        LoginFormField(
          label: "Last Name",
          placeholder: "Smith",
          icon: "person",
          text: $viewModel.signupLastName,
          error: .constant(nil),
          isSecure: false,
          keyboardType: .default,
          textContentType: .familyName,
          onBlur: {}
        )

        LoginFormField(
          label: "Email",
          placeholder: invite.email,
          icon: "envelope",
          text: .constant(invite.email),
          error: .constant(nil),
          isSecure: false,
          keyboardType: .emailAddress,
          textContentType: .emailAddress,
          onBlur: {}
        )
        .disabled(true)

        if invite.role == "player" {
          dateOfBirthField
        }

        VStack(alignment: .leading, spacing: 4) {
          LoginFormField(
            label: "Password",
            placeholder: "Create a strong password",
            icon: "lock",
            text: $viewModel.signupPassword,
            error: .constant(nil),
            isSecure: true,
            keyboardType: .default,
            textContentType: .newPassword,
            onBlur: {}
          )

          PasswordStrengthIndicator(password: viewModel.signupPassword)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }

        LoginFormField(
          label: "Confirm Password",
          placeholder: "Re-enter your password",
          icon: "lock.fill",
          text: $viewModel.signupConfirmPassword,
          error: .constant(nil),
          isSecure: true,
          keyboardType: .default,
          textContentType: .newPassword,
          onBlur: {}
        )

        TermsCheckbox(
          isChecked: $viewModel.signupAgreeToTerms,
          onTermsPressed: { presentedLegal = .termsOfService },
          onPrivacyPressed: { presentedLegal = .privacyPolicy }
        )
      }

      gradientButton(
        label: "Create account and connect",
        isLoading: viewModel.isAccepting
      ) {
        Task { await viewModel.signupAndConnect() }
      }

      declineButton(loading: viewModel.isDeclining)
    }
  }

  private var dateOfBirthField: some View {
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
        selection: $viewModel.signupDateOfBirth,
        in: ...Date(),
        displayedComponents: .date
      )
      .datePickerStyle(.compact)
      .labelsHidden()
    }
  }

  private func gradientButton(label: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Text(isLoading ? "Please wait..." : label)
          .font(.callout.weight(.semibold))
        if isLoading {
          ProgressView()
            .tint(.white)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .foregroundStyle(.white)
      .background(LinearGradient.primaryButton)
      .clipShape(.rect(cornerRadius: 8))
      .opacity(isLoading ? 0.7 : 1)
    }
    .disabled(isLoading)
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
