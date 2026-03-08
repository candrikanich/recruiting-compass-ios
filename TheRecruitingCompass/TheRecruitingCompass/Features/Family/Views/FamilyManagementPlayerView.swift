import SwiftUI

struct FamilyManagementPlayerView: View {
  @Bindable var viewModel: FamilyManagementViewModel

  var body: some View {
    ScrollView {
      VStack(spacing: FamilyConstants.Spacing.large) {
        familyCodeCard
        inviteByEmailCard
        pendingInvitationsSection
        familyMembersSection
      }
      .padding(.horizontal, FamilyConstants.Spacing.medium)
      .padding(.top, FamilyConstants.Spacing.medium)
    }
    .confirmationDialog(
      "Regenerate Family Code",
      isPresented: $viewModel.showRegenerateConfirmation,
      titleVisibility: .visible
    ) {
      Button("Regenerate", role: .destructive) {
        Task { await viewModel.regenerateCode() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure? The old code will stop working and anyone trying to join with the old code will not be able to.")
    }
    .confirmationDialog(
      "Remove Family Member",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Remove", role: .destructive) {
        Task { await viewModel.removeMember() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      if let member = viewModel.memberToRemove,
         let name = member.user?.fullName ?? member.user?.email {
        Text("Remove \(name) from family?")
      }
    }
  }

  // MARK: - Family Code Card
  private var familyCodeCard: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      Text("Your Family Code")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let code = viewModel.familyCode {
        VStack(spacing: FamilyConstants.Spacing.small) {
          Text(code)
            .font(.system(.largeTitle, design: .monospaced).weight(.bold))
            .tracking(2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FamilyConstants.Spacing.medium)
            .background(Color.gray.opacity(0.1))
            .clipShape(.rect(cornerRadius: 12))
            .accessibilityLabel(FamilyUtilities.formatCodeForVoiceOver(code))

          if let date = viewModel.formattedCodeGeneratedAt {
            Text("Created \(date)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          VStack(spacing: FamilyConstants.Spacing.small) {
            HStack(spacing: FamilyConstants.Spacing.small) {
              Button(action: { viewModel.copyCodeToClipboard() }) {
                Label("Copy", systemImage: "doc.on.doc")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .accessibilityLabel("Copy family code to clipboard")

              ShareLink(
                item: "Join my family on The Recruiting Compass with code: \(code)",
                label: {
                  Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                }
              )
              .buttonStyle(.bordered)
              .accessibilityLabel("Share family code")
            }

            Button(action: { viewModel.confirmRegenerateCode() }) {
              Label("Regenerate", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityLabel("Regenerate family code")
            .accessibilityHint("Creates a new code and invalidates the old one")
          }
        }
      } else {
        ProgressView()
          .accessibilityLabel("Loading family code")
          .frame(maxWidth: .infinity)
          .padding(.vertical, FamilyConstants.Spacing.extraLarge)
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color(.systemBackground))
    .clipShape(.rect(cornerRadius: 12))
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
  }

  // MARK: - Invite by Email Card
  private var inviteByEmailCard: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      Text("Invite Parent by Email")
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
        TextField("parent@example.com", text: $viewModel.inviteEmail)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.emailAddress)
          .textContentType(.emailAddress)
          .autocapitalization(.none)
          .accessibilityLabel("Parent email address")

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
        .accessibilityLabel("Send invite")
        .accessibilityHint(viewModel.isEmailInviteValid
          ? "Send email invite to the entered address"
          : "Enter a valid email to enable")
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color(.systemBackground))
    .clipShape(.rect(cornerRadius: 12))
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
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
            .accessibilityLabel("Resend invite to \(invite.invitedEmail)")

            Button("Revoke") {
              Task { await viewModel.revokeInvitation(invite) }
            }
            .font(.caption)
            .foregroundStyle(.red)
            .buttonStyle(.bordered)
            .tint(.red)
            .accessibilityLabel("Revoke invite to \(invite.invitedEmail)")
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

  private func formattedExpiry(_ isoString: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: isoString) else { return "unknown" }
    return DateFormatter.familyCodeDate.string(from: date)
  }

  // MARK: - Family Members Section
  private var familyMembersSection: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      HStack {
        Text("Family Members")
          .font(.headline)
        Spacer()
        Text("\(viewModel.familyMembers.count)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if viewModel.loadingMembers {
        ProgressView()
          .accessibilityLabel("Loading family members")
          .frame(maxWidth: .infinity)
          .padding(.vertical, FamilyConstants.Spacing.extraLarge)
      } else if viewModel.familyMembers.isEmpty {
        emptyMembersState
      } else {
        membersList
      }
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color(.systemBackground))
    .clipShape(.rect(cornerRadius: 12))
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
  }

  private var emptyMembersState: some View {
    VStack(spacing: FamilyConstants.Spacing.small) {
      Image(systemName: "person.2.slash")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text("No family members yet")
        .font(.headline)
      Text("Share your family code to invite parents")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, FamilyConstants.Spacing.extraLarge)
    .frame(maxWidth: .infinity)
  }

  private var membersList: some View {
    VStack(spacing: FamilyConstants.Spacing.small) {
      ForEach(viewModel.familyMembers) { member in
        FamilyMemberCard(
          member: member,
          onRemove: {
            viewModel.confirmRemoveMember(member)
          }
        )
      }
    }
  }

  // MARK: - Helpers
  private func formatCodeForVoiceOver(_ code: String) -> String {
    let parts = code.split(separator: "-")
    guard parts.count == 2 else { return code }
    let prefix = String(parts[0])
    let digits = String(parts[1]).map { String($0) }.joined(separator: " ")
    return "\(prefix) dash \(digits)"
  }

}
