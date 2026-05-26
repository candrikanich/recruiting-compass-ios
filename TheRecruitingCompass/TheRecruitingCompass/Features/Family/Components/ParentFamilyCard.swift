import SwiftUI

struct ParentFamilyCard: View {
  let family: ParentFamilyData

  var body: some View {
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
    .padding(FamilyConstants.Spacing.small)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(cardAccessibilityLabel)
  }

  var cardAccessibilityLabel: String {
    "\(family.familyName), code \(FamilyUtilities.formatCodeForVoiceOver(family.familyCode)), joined"
  }
}
