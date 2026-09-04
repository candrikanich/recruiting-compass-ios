import SwiftUI

struct RoleSelectionCard: View {
  let role: UserRole
  let isSelected: Bool
  let action: () -> Void
  @ScaledMetric(relativeTo: .title2) private var roleIconSize: CGFloat = 28
  @ScaledMetric(relativeTo: .title2) private var checkmarkSize: CGFloat = 24

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: role.icon)
            .font(.system(size: roleIconSize))
            .foregroundStyle(.white)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 4) {
            Text(role.displayName)
              .font(.callout.weight(.semibold))
              .foregroundStyle(.white)

            Text(role.description)
              .font(.caption)
              .foregroundStyle(.white.opacity(0.85))
              .lineLimit(2)
          }

          Spacer()

          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: checkmarkSize))
            .foregroundStyle(
              isSelected
                ? .white
                : .white.opacity(0.5)
            )
            .accessibilityHidden(true)
        }
      }
      .padding(16)
      .background(
        isSelected
          ? Color.primaryGreen
          : Color.primaryGreen.opacity(0.85)
      )
      .clipShape(.rect(cornerRadius: 12))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(role.displayName) role"))
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityHint(role.description)
    .accessibilityAddTraits(.isButton)
  }
}

#Preview {
  @Previewable @State var selectedRole: UserRole? = .parent

  VStack(spacing: 12) {
    RoleSelectionCard(
      role: .parent,
      isSelected: selectedRole == .parent,
      action: { selectedRole = .parent }
    )

    RoleSelectionCard(
      role: .player,
      isSelected: selectedRole == .player,
      action: { selectedRole = .player }
    )
  }
  .padding()
}
