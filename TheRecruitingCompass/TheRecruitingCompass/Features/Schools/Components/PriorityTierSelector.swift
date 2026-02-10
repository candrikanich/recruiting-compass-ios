import SwiftUI

struct PriorityTierSelector: View {
  let selectedTier: PriorityTier?
  let isUpdating: Bool
  let onSelect: (PriorityTier?) async -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var buttonHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 48 : 44
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Priority Tier")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        if isUpdating {
          ProgressView()
            .scaleEffect(0.8)
            .accessibilityLabel("Updating priority tier")
        }

        Spacer()
      }

      HStack(spacing: 8) {
        tierButton(tier: nil, label: "None")

        tierButton(tier: .a, label: "A")

        tierButton(tier: .b, label: "B")

        tierButton(tier: .c, label: "C")
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal)
    .disabled(isUpdating)
  }

  @ViewBuilder
  private func tierButton(tier: PriorityTier?, label: String) -> some View {
    Button {
      Task {
        await onSelect(tier)
      }
    } label: {
      Text(label)
        .font(.body)
        .fontWeight(selectedTier == tier ? .semibold : .regular)
        .foregroundStyle(selectedTier == tier ? .white : .primary)
        .frame(maxWidth: .infinity, minHeight: buttonHeight)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(backgroundColor(for: tier))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor(for: tier), lineWidth: selectedTier == tier ? 2 : 1)
        )
        .contentShape(Rectangle())
    }
    .accessibilityLabel(accessibilityLabel(for: tier))
    .accessibilityHint(accessibilityHint(for: tier))
    .accessibilityAddTraits(selectedTier == tier ? [.isButton, .isSelected] : .isButton)
  }

  private func backgroundColor(for tier: PriorityTier?) -> Color {
    if selectedTier == tier {
      return tier?.badgeColor ?? .accentBlue
    } else {
      return Color(.systemGray6)
    }
  }

  private func borderColor(for tier: PriorityTier?) -> Color {
    if selectedTier == tier {
      return tier?.badgeColor ?? .accentBlue
    } else {
      return Color(.systemGray4)
    }
  }

  private func accessibilityLabel(for tier: PriorityTier?) -> String {
    if let tier {
      return "Priority tier \(tier.displayName)"
    } else {
      return "No priority tier"
    }
  }

  private func accessibilityHint(for tier: PriorityTier?) -> String {
    if selectedTier == tier {
      return "Currently selected"
    } else {
      return "Double tap to select"
    }
  }
}

#Preview("Selected A") {
  PriorityTierSelector(
    selectedTier: .a,
    isUpdating: false,
    onSelect: { _ in }
  )
  .padding()
}

#Preview("Selected None") {
  PriorityTierSelector(
    selectedTier: nil,
    isUpdating: false,
    onSelect: { _ in }
  )
  .padding()
}

#Preview("Updating") {
  PriorityTierSelector(
    selectedTier: .b,
    isUpdating: true,
    onSelect: { _ in }
  )
  .padding()
}
