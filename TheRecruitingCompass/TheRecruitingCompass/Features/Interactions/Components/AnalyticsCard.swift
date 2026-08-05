import SwiftUI

struct AnalyticsCard: View {
  let title: String
  let value: Int
  let icon: String
  let backgroundColor: Color
  let iconColor: Color
  var accessibilityLabelOverride: String?

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: iconSize))
          .foregroundStyle(iconColor)
          .accessibilityHidden(true)

        Spacer()

        Text("\(value)")
          .font(.title.weight(.bold))
          .foregroundStyle(.primary)
      }

      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .leading)
    .background(backgroundColor)
    .clipShape(.rect(cornerRadius: 12))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: - Computed Properties

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 26 : 22
  }

  private var cardHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 100 : 80
  }

  var accessibilityLabel: String {
    if let override = accessibilityLabelOverride {
      return override
    }
    let interactionWord = value == 1 ? "interaction" : "interactions"

    switch title {
    case "Total":
      return "\(value) total \(interactionWord)"
    case "Outbound":
      return "\(value) outbound \(interactionWord)"
    case "Inbound":
      return "\(value) inbound \(interactionWord)"
    case "This Week":
      return "\(value) \(interactionWord) this week"
    default:
      return "\(value) \(title.lowercased()) \(interactionWord)"
    }
  }
}
