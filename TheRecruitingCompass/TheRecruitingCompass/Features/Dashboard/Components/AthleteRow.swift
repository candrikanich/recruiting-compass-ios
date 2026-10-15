import SwiftUI

struct AthleteRow: View {
  let athlete: FamilyMember
  var familyLabel: String?
  let isSelected: Bool
  let onSelect: () -> Void

  private var accessibilityText: String {
    let base = String(localized: "\(athlete.role.capitalized) - ID: \(athlete.userId.prefix(8))")
    guard let familyLabel else { return base }
    return String(localized: "\(familyLabel), \(base)")
  }

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        Image(systemName: "person.circle.fill")
          .font(.brand(.title2))
          .foregroundStyle(isSelected ? Color.accentPrimary : Color.iconGray)

        VStack(alignment: .leading, spacing: 2) {
          Text(athlete.role.capitalized)
            .font(.brand(.subheadline))
            .fontWeight(.semibold)
            .foregroundStyle(Color.darkSlate)

          if let familyLabel {
            Text(familyLabel)
              .font(.brand(.caption))
              .foregroundStyle(Color.secondaryText)
          }

          Text("ID: \(athlete.userId.prefix(8))...")
            .font(.brand(.caption))
            .foregroundStyle(Color.secondaryText)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentPrimary)
        }
      }
      .padding(12)
      .background(isSelected ? Color.accentPrimary.opacity(0.1) : Color(.secondarySystemBackground))
      .clipShape(.rect(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityHint("Double tap to select this athlete")
  }
}
