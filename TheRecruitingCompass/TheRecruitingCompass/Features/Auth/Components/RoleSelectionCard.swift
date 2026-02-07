import SwiftUI

struct RoleSelectionCard: View {
  let role: UserRole
  let isSelected: Bool
  let action: () -> Void
  @Environment(\.sizeCategory) var sizeCategory

  private var roleIconSize: CGFloat {
    sizeCategory >= .extraLarge ? 30 : 28
  }

  private var checkmarkSize: CGFloat {
    sizeCategory >= .extraLarge ? 26 : 24
  }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: role.icon)
            .font(.system(size: roleIconSize))
            .foregroundColor(Color.primaryGreen)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 4) {
            Text(role.displayName)
              .font(.callout.weight(.semibold))
              .foregroundColor(Color.darkSlate)

            Text(role.description)
              .font(.caption)
              .foregroundColor(Color.secondaryText)
              .lineLimit(2)
          }

          Spacer()

          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: checkmarkSize))
            .foregroundColor(
              isSelected
                ? Color.accentBlue
                : Color.borderGray
            )
            .accessibilityHidden(true)
        }
      }
      .padding(16)
      .background(Color.white)
      .border(
        isSelected ? Color.accentBlue : Color.borderGray,
        width: 2
      )
      .cornerRadius(8)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(role.displayName) role")
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityHint(role.description)
    .accessibilityAddTraits(.isButton)
  }
}

#Preview {
  @State var selectedRole: UserRole? = .parent

  return VStack(spacing: 12) {
    RoleSelectionCard(
      role: .parent,
      isSelected: selectedRole == .parent,
      action: { selectedRole = .parent }
    )

    RoleSelectionCard(
      role: .student,
      isSelected: selectedRole == .student,
      action: { selectedRole = .student }
    )

    RoleSelectionCard(
      role: .player,
      isSelected: selectedRole == .player,
      action: { selectedRole = .player }
    )
  }
  .padding()
}
