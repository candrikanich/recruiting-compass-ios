import SwiftUI

struct AthleteRow: View {
  let athlete: FamilyMember
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        Image(systemName: "person.circle.fill")
          .font(.title2)
          .foregroundStyle(isSelected ? Color.primaryGreen : Color.iconGray)

        VStack(alignment: .leading, spacing: 2) {
          Text(athlete.role.capitalized)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.darkSlate)

          Text("ID: \(athlete.userId.prefix(8))...")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.primaryGreen)
        }
      }
      .padding(12)
      .background(isSelected ? Color.primaryGreen.opacity(0.1) : Color(.secondarySystemBackground))
      .clipShape(.rect(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(athlete.role.capitalized) - ID: \(athlete.userId.prefix(8))"))
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityHint("Double tap to select this athlete")
  }
}
