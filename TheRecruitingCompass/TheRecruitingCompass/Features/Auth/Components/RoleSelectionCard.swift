import SwiftUI

struct RoleSelectionCard: View {
  let role: UserRole
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: role.icon)
            .font(.system(size: 28))
            .foregroundColor(Color(red: 0.024, green: 0.588, blue: 0.412))

          VStack(alignment: .leading, spacing: 4) {
            Text(role.displayName)
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(Color(red: 0.216, green: 0.263, blue: 0.322))

            Text(role.description)
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))
              .lineLimit(2)
          }

          Spacer()

          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundColor(
              isSelected
                ? Color(red: 0.149, green: 0.388, blue: 0.931)
                : Color(red: 0.827, green: 0.843, blue: 0.863)
            )
        }
      }
      .padding(16)
      .background(Color.white)
      .border(
        isSelected ? Color(red: 0.149, green: 0.388, blue: 0.931) : Color(red: 0.827, green: 0.843, blue: 0.863),
        width: 2
      )
      .cornerRadius(8)
    }
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
