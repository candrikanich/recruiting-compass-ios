import SwiftUI

struct FilterChip: View {
  enum Style {
    case outlined
    case filled
  }

  let label: String
  let style: Style
  let onRemove: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  init(
    label: String,
    style: Style = .outlined,
    onRemove: @escaping () -> Void
  ) {
    self.label = label
    self.style = style
    self.onRemove = onRemove
  }

  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.subheadline)
        .fontWeight(style == .filled ? .medium : .regular)

      Button {
        onRemove()
      } label: {
        removeIcon
          .font(iconFont)
          .bold()
          .frame(minWidth: 24, minHeight: 24)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(String(localized: "Remove \(label) filter"))
      .accessibilityHint(style == .filled ? "Double tap to remove this filter" : "")
    }
    .foregroundStyle(foregroundColor)
    .padding(.horizontal, horizontalPadding)
    .padding(.vertical, verticalPadding)
    .frame(minHeight: minHeight)
    .background(backgroundColor)
    .clipShape(Capsule())
    .accessibilityElement(children: style == .filled ? .combine : .contain)
  }

  private var removeIcon: Image {
    switch style {
    case .outlined:
      return Image(systemName: "xmark")
    case .filled:
      return Image(systemName: "xmark.circle.fill")
    }
  }

  private var iconFont: Font {
    style == .outlined ? .caption2 : .caption
  }

  private var foregroundColor: Color {
    switch style {
    case .outlined:
      return Color.accentBlue
    case .filled:
      return .white
    }
  }

  private var backgroundColor: Color {
    switch style {
    case .outlined:
      return Color.accentBlue.opacity(0.12)
    case .filled:
      return Color.blue
    }
  }

  private var horizontalPadding: CGFloat {
    style == .outlined ? 10 : 12
  }

  private var verticalPadding: CGFloat {
    6
  }

  private var minHeight: CGFloat {
    switch style {
    case .outlined:
      return 0
    case .filled:
      if sizeCategory.isAccessibilityCategory {
        return 44
      }
      return 32
    }
  }
}

extension ContentSizeCategory {
  var isAccessibilityCategory: Bool {
    switch self {
    case .accessibilityMedium, .accessibilityLarge,
         .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
         .accessibilityExtraExtraExtraLarge:
      return true
    default:
      return false
    }
  }
}

#Preview("Outlined Style") {
  FilterChip(label: "Filter Name", style: .outlined) {}
  .padding()
}

#Preview("Filled Style") {
  FilterChip(label: "Filter Name", style: .filled) {}
  .padding()
}
