import SwiftUI

struct NotificationFilterChips: View {
  @Binding var selectedType: NotificationType?
  let onFilterChanged: (NotificationType?) -> Void

  var chipDisplayLabels: [String] {
    ["All"] + NotificationType.allCases.map { "\($0.emoji) \($0.label)" }
  }

  var chipAccessibilityLabels: [String] {
    let allActive = selectedType == nil
    var labels = [NotificationToggleChip.accessibilityLabel(for: "All", isActive: allActive)]
    for type in NotificationType.allCases {
      let isActive = selectedType == type
      labels.append(NotificationToggleChip.accessibilityLabel(for: "\(type.emoji) \(type.label)", isActive: isActive))
    }
    return labels
  }

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
