import SwiftUI

struct FamilyManagementPlayerView: View {
  @Bindable var viewModel: FamilyManagementViewModel

  var body: some View {
    ScrollView {
      VStack(spacing: FamilyConstants.Spacing.large) {
        familyCodeCard
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
            .cornerRadius(12)
            .accessibilityLabel(FamilyUtilities.formatCodeForVoiceOver(code))

          if let date = viewModel.formattedCodeGeneratedAt {
            Text("Created \(date)")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          HStack(spacing: FamilyConstants.Spacing.small) {
            Button(action: { viewModel.copyCodeToClipboard() }) {
              Label("Copy", systemImage: "doc.on.doc")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Copy family code to clipboard")

            Button(action: { viewModel.shareCode() }) {
              Label("Share", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Share family code")

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
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
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
          .foregroundColor(.secondary)
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
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
  }

  private var emptyMembersState: some View {
    VStack(spacing: FamilyConstants.Spacing.small) {
      Image(systemName: "person.2.slash")
        .font(.largeTitle)
        .foregroundColor(.secondary)
        .accessibilityHidden(true)
      Text("No family members yet")
        .font(.headline)
      Text("Share your family code to invite parents")
        .font(.subheadline)
        .foregroundColor(.secondary)
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

  private func shareCode() {
    guard let code = viewModel.familyCode else { return }
    let text = "Join my family on The Recruiting Compass with code: \(code)"

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let rootVC = window.rootViewController else {
      return
    }

    let activityVC = UIActivityViewController(
      activityItems: [text],
      applicationActivities: nil
    )

    if let popover = activityVC.popoverPresentationController {
      popover.sourceView = window
      popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }

    rootVC.present(activityVC, animated: true)
  }
}
