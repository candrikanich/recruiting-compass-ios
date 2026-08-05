import SwiftUI

struct NotificationToggleChip: View {
  let label: String
  let isActive: Bool
  let action: () -> Void

  static func accessibilityLabel(for label: String, isActive: Bool) -> String {
    "\(label) filter\(isActive ? ", selected" : "")"
  }

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isActive ? .white : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.accentBlue : Color(.systemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.3), lineWidth: isActive ? 0 : 1)
        )
        .clipShape(.rect(cornerRadius: 8))
    }
    .accessibilityLabel(NotificationToggleChip.accessibilityLabel(for: label, isActive: isActive))
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
  }
}
