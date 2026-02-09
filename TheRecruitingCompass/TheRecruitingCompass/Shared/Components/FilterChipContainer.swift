import SwiftUI

struct FilterChipContainer<Content: View>: View {
  enum Style {
    case outlined
    case filled
  }

  let hasFilters: Bool
  let style: Style
  let onClearAll: () -> Void
  @ViewBuilder let chips: () -> Content

  init(
    hasFilters: Bool,
    style: Style = .outlined,
    onClearAll: @escaping () -> Void,
    @ViewBuilder chips: @escaping () -> Content
  ) {
    self.hasFilters = hasFilters
    self.style = style
    self.onClearAll = onClearAll
    self.chips = chips
  }

  var body: some View {
    if hasFilters {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          chips()

          clearAllButton
        }
        .padding(.horizontal, 16)
      }
    }
  }

  private var clearAllButton: some View {
    Button("Clear all") {
      onClearAll()
    }
    .font(.subheadline)
    .fontWeight(style == .filled ? .medium : .regular)
    .foregroundStyle(clearAllColor)
    .accessibilityLabel("Clear all filters")
    .accessibilityHint("Removes all active filters")
  }

  private var clearAllColor: Color {
    switch style {
    case .outlined:
      return Color.accentBlue
    case .filled:
      return .white
    }
  }
}

#Preview("Outlined Style") {
  FilterChipContainer(
    hasFilters: true,
    style: .outlined,
    onClearAll: { print("Clear all") }
  ) {
    FilterChip(label: "Role: Head Coach", style: .outlined) {
      print("Remove role")
    }
    FilterChip(label: "Last 30 days", style: .outlined) {
      print("Remove last contact")
    }
  }
}

#Preview("Filled Style") {
  FilterChipContainer(
    hasFilters: true,
    style: .filled,
    onClearAll: { print("Clear all") }
  ) {
    FilterChip(label: "Division: D1", style: .filled) {
      print("Remove division")
    }
    FilterChip(label: "Status: Interested", style: .filled) {
      print("Remove status")
    }
  }
}

#Preview("No Filters") {
  FilterChipContainer(
    hasFilters: false,
    style: .outlined,
    onClearAll: { print("Clear all") }
  ) {
    FilterChip(label: "Should not show", style: .outlined) {
      print("Remove")
    }
  }
}
