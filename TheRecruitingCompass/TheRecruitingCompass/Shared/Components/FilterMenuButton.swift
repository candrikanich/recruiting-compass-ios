import SwiftUI

struct FilterMenuButton: View {
  enum Style {
    case capsule
    case rounded
  }

  let label: String
  let isActive: Bool
  let style: Style

  init(
    label: String,
    isActive: Bool,
    style: Style = .capsule
  ) {
    self.label = label
    self.isActive = isActive
    self.style = style
  }

  var body: some View {
    HStack(spacing: style == .capsule ? 4 : 6) {
      Text(label)
        .font(.subheadline)
        .fontWeight(style == .rounded && isActive ? .semibold : .regular)

      Image(systemName: "chevron.down")
        .font(.caption)
        .accessibilityHidden(true)
    }
    .foregroundStyle(foregroundColor)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(minHeight: 44)
    .background(backgroundColor)
    .modifier(ShapeModifier(style: style))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(accessibilityLabel)
  }

  private var foregroundColor: Color {
    switch style {
    case .capsule:
      return isActive ? Color.accentBlue : Color.primary
    case .rounded:
      return isActive ? .white : .primary
    }
  }

  private var backgroundColor: Color {
    switch style {
    case .capsule:
      return isActive ? Color.accentBlue.opacity(0.12) : Color(.secondarySystemBackground)
    case .rounded:
      return isActive ? Color.blue : Color(.systemGray6)
    }
  }

  var accessibilityLabel: String {
    if isActive {
      return String(localized: "\(label), active")
    }
    return label
  }
}

private struct ShapeModifier: ViewModifier {
  let style: FilterMenuButton.Style

  func body(content: Content) -> some View {
    switch style {
    case .capsule:
      content.clipShape(Capsule())
    case .rounded:
      content.clipShape(.rect(cornerRadius: 8))
    }
  }
}

#Preview("Capsule Style") {
  VStack(spacing: 16) {
    FilterMenuButton(label: "Active", isActive: true, style: .capsule)
    FilterMenuButton(label: "Inactive", isActive: false, style: .capsule)
  }
  .padding()
}

#Preview("Rounded Style") {
  VStack(spacing: 16) {
    FilterMenuButton(label: "Active", isActive: true, style: .rounded)
    FilterMenuButton(label: "Inactive", isActive: false, style: .rounded)
  }
  .padding()
}
