import SwiftUI

/// Shown instead of the app to a signed-in user who belongs to no family (web `/family/setup`). There is no
/// skip. Still reachable from here, as on web: join by invite link (a deep link opens its own sheet), join by
/// code, account deletion, the legal pages and sign-out.
struct FamilySetupView: View {
  @Environment(AuthManager.self) private var authManager
  @State private var viewModel: FamilySetupViewModel
  @State private var presentedLegal: LegalDocument?
  @State private var signOutError: String?

  init(familyManager: FamilyManager) {
    _viewModel = State(initialValue: FamilySetupViewModel(
      familyService: FamilyServiceImpl(supabaseManager: .shared),
      authManager: AuthManager.shared,
      onMembershipChanged: { await familyManager.loadFamilyData() }
    ))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header
          if viewModel.isChecking {
            ProgressView("Checking your family\u{2026}")
              .frame(maxWidth: .infinity)
          } else {
            choices
          }
          accountLinks
        }
        .padding()
      }
      .navigationTitle("Your family")
      .navigationBarTitleDisplayMode(.inline)
      .task { await viewModel.checkForPendingInvite() }
      .sheet(item: $presentedLegal) { $0.view }
    }
  }

  @ViewBuilder
  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Create or join your family")
        .font(.brand(.title2, weight: .bold))
        .accessibilityAddTraits(.isHeader)
      Text("Every Recruiting Compass account belongs to a family, so players and parents share one recruiting plan.")
        .font(.brand(.subheadline))
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var choices: some View {
    if let message = viewModel.errorMessage {
      Text(message)
        .font(.brand(.footnote))
        .foregroundStyle(.red)
        .accessibilityIdentifier("family-setup-error")
    }

    if viewModel.offersCreate {
      createSection
    } else {
      inviteNotice
    }
    joinSection
  }

  @ViewBuilder
  private var inviteNotice: some View {
    Label {
      Text("You've been invited to join a family. Open the invitation link from your email to join it, "
        + "or enter the family code below. If you can't find the email, ask the person who invited you to resend it.")
        .font(.brand(.subheadline))
    } icon: {
      Image(systemName: "envelope.badge")
        .accessibilityHidden(true)
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .accessibilityIdentifier("pending-email-invite")
  }

  @ViewBuilder
  private var createSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Start a new family").font(.brand(.headline))
      Text("You'll get a family code to share with the people you want to invite.")
        .font(.brand(.subheadline))
        .foregroundStyle(.secondary)
      Button {
        Task { await viewModel.createFamily() }
      } label: {
        Text("Create my family").frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isSubmitting)
      .accessibilityIdentifier("create-family")
    }
  }

  @ViewBuilder
  private var joinSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Join with a family code").font(.brand(.headline))
      Text("Already invited? Enter the code a family member shared with you.")
        .font(.brand(.subheadline))
        .foregroundStyle(.secondary)
      TextField("FAM-ABC123", text: $viewModel.familyCode)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .textFieldStyle(.roundedBorder)
        .frame(minHeight: 44)
        .accessibilityLabel("Family code")
        .accessibilityIdentifier("family-code-input")
      Button {
        Task { await viewModel.joinWithCode() }
      } label: {
        Text("Join family").frame(maxWidth: .infinity, minHeight: 44)
      }
      .buttonStyle(.bordered)
      .disabled(viewModel.isSubmitting || viewModel.familyCode.trimmingCharacters(in: .whitespaces).isEmpty)
      .accessibilityIdentifier("join-family")
    }
  }

  @ViewBuilder
  private var accountLinks: some View {
    VStack(alignment: .leading, spacing: 4) {
      Divider().padding(.bottom, 8)
      NavigationLink("Account and delete my account") { ProfileView() }
        .frame(minHeight: 44)
      Button("Terms of Service") { presentedLegal = .termsOfService }
        .frame(minHeight: 44)
      Button("Privacy Policy") { presentedLegal = .privacyPolicy }
        .frame(minHeight: 44)
      Button("Sign out", role: .destructive) { signOut() }
        .frame(minHeight: 44)
        .accessibilityIdentifier("family-setup-sign-out")
      if let signOutError {
        Text(signOutError).font(.brand(.footnote)).foregroundStyle(.red)
      }
    }
    .font(.brand(.body))
  }

  private func signOut() {
    Task {
      do {
        try await authManager.logout()
      } catch {
        signOutError = error.localizedDescription
      }
    }
  }
}

/// The family lookup failed, so the user is neither let into the app (they may have no family) nor sent to the
/// create screen (they may already have one).
struct FamilyLoadFailedView: View {
  let retry: () async -> Void

  var body: some View {
    ContentUnavailableView {
      Label("We couldn't load your family", systemImage: "wifi.exclamationmark")
    } description: {
      Text("Check your connection and try again.")
    } actions: {
      Button("Try again") { Task { await retry() } }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .accessibilityIdentifier("family-load-retry")
    }
  }
}
