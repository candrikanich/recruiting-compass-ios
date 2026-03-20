import SwiftUI

struct AthleteSelector: View {
  let athletes: [FamilyMember]
  let selectedAthleteId: String?
  let onSelect: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Select Athlete")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Divider()

      if athletes.isEmpty {
        Text("No linked athletes found")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
          .padding(.vertical)
          .accessibilityHint("Add family members to your account to select them here")
      } else {
        VStack(spacing: 8) {
          ForEach(athletes) { athlete in
            AthleteRow(
              athlete: athlete,
              isSelected: athlete.id == selectedAthleteId,
              onSelect: { onSelect(athlete.id) }
            )
          }
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}

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
    .accessibilityLabel("\(athlete.role.capitalized) - ID: \(athlete.userId.prefix(8))")
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityHint("Double tap to select this athlete")
  }
}

#Preview {
  AthleteSelector(
    athletes: [
      FamilyMember(
        id: "1",
        userId: "user-1",
        familyUnitId: "family-1",
        role: "athlete",
        addedAt: "2026-01-01T12:00:00Z",
        user: nil
      ),
      FamilyMember(
        id: "2",
        userId: "user-2",
        familyUnitId: "family-1",
        role: "athlete",
        addedAt: "2026-01-01T12:00:00Z",
        user: nil
      )
    ],
    selectedAthleteId: "1",
    onSelect: { _ in }
  )
  .padding()
}
