import SwiftUI

struct FamilyManagementParentView: View {
  @Bindable var viewModel: FamilyManagementViewModel

  var body: some View {
    ScrollView {
      VStack(spacing: FamilyConstants.Spacing.large) {
        joinFamilyCard
        inviteByEmailCard
        pendingInvitationsSection
        myFamiliesSection
      }
      .padding(.horizontal, FamilyConstants.Spacing.medium)
      .padding(.top, FamilyConstants.Spacing.medium)
    }
  }

  // MARK: - Join Family Card
  @ViewBuilder
  private var joinFamilyCard: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      Text("Join a Family")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text("Enter a family code shared by a player")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      VStack(spacing: FamilyConstants.Spacing.small) {
        TextField("FAM-XXXXXX", text: $viewModel.codeInput)
          .textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled(true)
          .font(.system(.body, design: .monospaced))
          .onChange(of: viewModel.codeInput) { _, _ in
            viewModel.formatCodeInput()
          }
          .accessibilityLabel(String(localized: "Enter family code"))
          .accessibilityHint("Enter a code like FAM-XXXXXX")

        Button(action: { Task { await viewModel.joinFamily() } }) {
          if viewModel.isLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(.white)
          } else {
            Text("Join Family")
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FamilyConstants.Spacing.small)
        .background(viewModel.isCodeInputValid && !viewModel.isLoading ? Color.blue : Color.gray)
        .foregroundStyle(.white)
        .clipShape(.rect(cornerRadius: 8))
        .disabled(!viewModel.isCodeInputValid || viewModel.isLoading)
        .accessibilityLabel(String(localized: "Join family button"))
        .accessibilityHint(viewModel.isCodeInputValid ? "Join the family using the entered code" : "Enter a valid family code to enable")
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }

  // MARK: - Invite by Email Card
  @ViewBuilder
  private var inviteByEmailCard: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      Text("Invite Player by Email")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

        Text("They'll receive a link to join your family.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text("Invites expire after 30 days.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: FamilyConstants.Spacing.small) {
        TextField("player@example.com", text: $viewModel.inviteEmail)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .autocapitalization(.none)
          .accessibilityLabel(String(localized: "Player email address"))

        Button {
          Task { await viewModel.sendEmailInvite() }
        } label: {
          if viewModel.isLoading {
            ProgressView().tint(.white)
          } else {
            Text("Send")
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(viewModel.isEmailInviteValid ? Color.accentColor : Color.gray)
        .foregroundStyle(.white)
        .clipShape(.rect(cornerRadius: 8))
        .disabled(!viewModel.isEmailInviteValid || viewModel.isLoading)
        .accessibilityLabel(String(localized: "Send invite"))
        .accessibilityHint(viewModel.isEmailInviteValid
          ? "Send email invite to the entered address"
          : "Enter a valid email to enable")
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }

  @ViewBuilder
  private var pendingInvitationsSection: some View {
    if !viewModel.pendingInvitations.isEmpty {
      VStack(spacing: FamilyConstants.Spacing.medium) {
        HStack {
          Text("Pending Invitations")
            .font(.headline)
          Spacer()
          Text("\(viewModel.pendingInvitations.count)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        ForEach(viewModel.pendingInvitations) { invite in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(invite.invitedEmail)
                .font(.subheadline.weight(.medium))
              Text("Expires \(formattedExpiry(invite.expiresAt ?? ""))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Resend") {
              Task { await viewModel.resendInvitation(invite) }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .accessibilityLabel(String(localized: "Resend invite to \(invite.invitedEmail)"))

            Button("Revoke") {
              Task { await viewModel.revokeInvitation(invite) }
            }
            .font(.caption)
            .foregroundStyle(.red)
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityLabel(String(localized: "Revoke invite to \(invite.invitedEmail)"))
          }
          .padding(.vertical, 4)
        }
      }
      .padding(FamilyConstants.Spacing.medium)
      .background(Color(.systemBackground))
      .clipShape(.rect(cornerRadius: 12))
      .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
  }

  private static let expiryFormatter = ISO8601DateFormatter()

  private func formattedExpiry(_ isoString: String) -> String {
    guard let date = Self.expiryFormatter.date(from: isoString) else { return "unknown" }
    return DateFormatter.familyCodeDate.string(from: date)
  }

  // MARK: - My Families Section
  @ViewBuilder
  private var myFamiliesSection: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      HStack {
        Text("My Families")
          .font(.headline)
        Spacer()
        Text("\(viewModel.parentFamilies.count)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if viewModel.isLoading && viewModel.parentFamilies.isEmpty {
        ProgressView()
          .accessibilityLabel(String(localized: "Loading families"))
          .frame(maxWidth: .infinity)
          .padding(.vertical, FamilyConstants.Spacing.extraLarge)
      } else if viewModel.parentFamilies.isEmpty {
        emptyFamiliesState
      } else {
        familiesList
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }

  @ViewBuilder
  private var emptyFamiliesState: some View {
    VStack(spacing: FamilyConstants.Spacing.small) {
      Image(systemName: "person.2.slash")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text("No families joined yet")
        .font(.headline)
      Text("Ask a player to share their family code")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, FamilyConstants.Spacing.extraLarge)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var familiesList: some View {
    VStack(spacing: FamilyConstants.Spacing.small) {
      ForEach(viewModel.parentFamilies) { family in
        ParentFamilyCard(family: family)
      }
    }
  }
}
