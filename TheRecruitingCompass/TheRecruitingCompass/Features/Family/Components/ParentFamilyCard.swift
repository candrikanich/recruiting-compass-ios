import SwiftUI

struct ParentFamilyCard: View {
  let family: ParentFamilyData

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 8) {
        Text(family.familyName)
          .font(.headline)

        HStack(spacing: 8) {
          Text(family.familyCode)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)

          Spacer()

          Text("Joined")
            .font(.caption)
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
            FamilyMemberCard(member: member, onRemove: {}, showRemoveButton: false)
          }
        }
      }
    }
    .padding(FamilyConstants.Spacing.small)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
  }

  var cardAccessibilityLabel: String {
    String(localized: "\(family.familyName), code \(FamilyUtilities.formatCodeForVoiceOver(family.familyCode)), joined")
  }
}
