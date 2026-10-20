import SwiftUI

struct ParentFamilyCard: View {
  let family: ParentFamilyData
  /// Server-resolved family label (falls back to the stored name when none is known).
  let label: String
  var onRemoveMember: (FamilyMember) -> Void = { _ in }
  var onLeave: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 8) {
        Text(label)
          .font(.brand(.headline))

        HStack(spacing: 8) {
          Text(family.familyCode)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)

          Spacer()

          Text("Joined")
            .font(.brand(.caption))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.2))
            .foregroundStyle(.green)
            .clipShape(.rect(cornerRadius: 4))
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(cardAccessibilityLabel)

      if !family.members.isEmpty {
        VStack(spacing: FamilyConstants.Spacing.small) {
          ForEach(family.members) { member in
            FamilyMemberCard(member: member, onRemove: { onRemoveMember(member) })
          }
        }
      }

      leaveControl
    }
    .padding(FamilyConstants.Spacing.small)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
  }

  /// Leave follows the server's verdict only: enabled on `canLeave`, disabled with `leaveBlockedReason`,
  /// absent when the server said nothing.
  @ViewBuilder
  private var leaveControl: some View {
    if family.leaveControl.isVisible {
      VStack(alignment: .leading, spacing: 4) {
        Button(role: .destructive, action: onLeave) {
          Text("Leave Family")
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!family.leaveControl.isEnabled)
        .accessibilityLabel(String(localized: "Leave \(label)"))
        .accessibilityHint(family.leaveControl.reason ?? "")
        if let reason = family.leaveControl.reason {
          Text(reason)
            .font(.brand(.caption))
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  var cardAccessibilityLabel: String {
    String(localized: "\(label), code \(FamilyUtilities.formatCodeForVoiceOver(family.familyCode)), joined")
  }
}
