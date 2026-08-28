import SwiftUI

struct InviteJoinView: View {
  @State var viewModel: InviteJoinViewModel
  @State private var presentedLegal: LegalDocument?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      InviteJoinStateContent(viewModel: viewModel, presentedLegal: $presentedLegal, dismiss: dismiss)
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
}

private struct InviteJoinStateContent: View {
  @Bindable var viewModel: InviteJoinViewModel
  @Binding var presentedLegal: LegalDocument?
  let dismiss: DismissAction

  var body: some View {
    switch viewModel.state {
    case .loading:
      InviteJoinLoadingView()
    case .error(let err):
      InviteJoinErrorView(error: err, dismiss: dismiss)
    case .declined:
      InviteJoinDeclinedView(dismiss: dismiss)
    case .loaded(let invite):
      InviteJoinInviteContent(invite: invite, viewModel: viewModel, presentedLegal: $presentedLegal)
    }
  }
}

private struct InviteJoinLoadingView: View {
  var body: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Loading invite...")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct InviteJoinErrorView: View {
  let error: InviteError
  let dismiss: DismissAction

  var body: some View {
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
}

private struct InviteJoinDeclinedView: View {
  let dismiss: DismissAction

  var body: some View {
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
  case .expired: return String(localized: "This invite has expired")
  case .alreadyAccepted: return String(localized: "Already connected")
  case .notFound: return String(localized: "Invite not found")
  case .serverError: return String(localized: "Something went wrong")
  }
}

private struct InviteJoinInviteContent: View {
  let invite: InviteDetails
  @Bindable var viewModel: InviteJoinViewModel
  @Binding var presentedLegal: LegalDocument?

  var body: some View {
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
          InviteJoinAuthenticatedConnectSection(invite: invite, viewModel: viewModel)
        } else if invite.emailExists {
          InviteJoinLoginSection(invite: invite, viewModel: viewModel)
        } else {
          InviteJoinSignupSection(invite: invite, viewModel: viewModel, presentedLegal: $presentedLegal)
        }
      }
      .padding(24)
    }
  }
}

private struct InviteJoinAuthenticatedConnectSection: View {
  let invite: InviteDetails
  @Bindable var viewModel: InviteJoinViewModel

  var body: some View {
    VStack(spacing: 12) {
      AsyncButton(
        title: String(localized: "Connect to \(invite.familyName)"),
        loadingTitle: String(localized: "Please wait..."),
        isLoading: viewModel.isAccepting
      ) {
        Task { await viewModel.accept() }
      }

      declineButton(loading: viewModel.isDeclining) {
        Task { await viewModel.decline() }
      }
    }
  }
}

private struct InviteJoinLoginSection: View {
  let invite: InviteDetails
  @Bindable var viewModel: InviteJoinViewModel

  var body: some View {
    VStack(spacing: 16) {
      Text("Log in to connect your account.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      VStack(spacing: 12) {
        LoginFormField(
          label: String(localized: "Email"),
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
          label: String(localized: "Password"),
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

      AsyncButton(
        title: String(localized: "Log in and connect"),
        loadingTitle: String(localized: "Please wait..."),
        isLoading: viewModel.isAccepting
      ) {
        Task { await viewModel.accept() }
      }

      declineButton(loading: viewModel.isDeclining) {
        Task { await viewModel.decline() }
      }
    }
  }
}

private struct InviteJoinSignupSection: View {
  let invite: InviteDetails
  @Bindable var viewModel: InviteJoinViewModel
  @Binding var presentedLegal: LegalDocument?

  var body: some View {
    VStack(spacing: 16) {
      Text("Create an account to connect.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let err = viewModel.signupError {
        ErrorBanner(message: err, onDismiss: { viewModel.signupError = nil })
      }

      VStack(spacing: 12) {
        LoginFormField(
          label: String(localized: "First Name"),
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
          label: String(localized: "Last Name"),
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
          label: String(localized: "Email"),
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

        if invite.memberRole == .player {
          InviteJoinDateOfBirthField(viewModel: viewModel)
        }

        VStack(alignment: .leading, spacing: 4) {
          LoginFormField(
            label: String(localized: "Password"),
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
          label: String(localized: "Confirm Password"),
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

      AsyncButton(
        title: String(localized: "Create account and connect"),
        loadingTitle: String(localized: "Please wait..."),
        isLoading: viewModel.isAccepting
      ) {
        Task { await viewModel.signupAndConnect() }
      }

      declineButton(loading: viewModel.isDeclining) {
        Task { await viewModel.decline() }
      }
    }
  }
}

private struct InviteJoinDateOfBirthField: View {
  @Bindable var viewModel: InviteJoinViewModel

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
        selection: $viewModel.signupDateOfBirth,
        in: ...Date.now,
        displayedComponents: .date
      )
      .datePickerStyle(.compact)
      .labelsHidden()

      Text("Recruiting Compass is for ages 13 and up. By entering a date of birth, you confirm you are 13 or older.")
        .font(.caption)
        .foregroundStyle(Color.secondary)
    }
  }
}

private func declineButton(loading: Bool, action: @escaping () -> Void) -> some View {
  Button(role: .destructive, action: action) {
    Group {
      if loading {
        ProgressView().tint(.red)
      } else {
        Text("Decline invitation")
      }
    }
    .frame(maxWidth: .infinity)
    .frame(minHeight: 44)
  }
  .buttonStyle(.bordered)
  .tint(.red)
  .disabled(loading)
}
