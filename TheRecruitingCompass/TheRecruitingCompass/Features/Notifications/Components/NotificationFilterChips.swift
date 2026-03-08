import SwiftUI

struct NotificationFilterChips: View {
  @Binding var selectedType: NotificationType?
  let onFilterChanged: (NotificationType?) -> Void

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        NotificationToggleChip(
          label: "All",
          isActive: selectedType == nil
        ) {
          selectedType = nil
          onFilterChanged(nil)
        }

        ForEach(NotificationType.allCases, id: \.self) { type in
          NotificationToggleChip(
            label: "\(type.emoji) \(type.label)",
            isActive: selectedType == type
          ) {
            selectedType = type
            onFilterChanged(type)
          }
        }
      }
      .padding(.horizontal)
    }
    .scrollIndicators(.hidden)
    .accessibilityIdentifier("Filter notifications")
    .frame(minHeight: 44)
  }
}

private struct NotificationToggleChip: View {
  let label: String
  let isActive: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isActive ? .white : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color(hex: "#3B82F6") : Color(.systemBackground))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.secondary.opacity(0.3), lineWidth: isActive ? 0 : 1)
        )
        .clipShape(.rect(cornerRadius: 8))
    }
    .accessibilityLabel("\(label) filter\(isActive ? ", selected" : "")")
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
  }
}
