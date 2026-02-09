import SwiftUI

struct InteractionAnalyticsCards: View {
  let analytics: InteractionAnalytics

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ],
      spacing: 12
    ) {
      AnalyticsCard(
        title: "Total",
        value: analytics.totalCount,
        icon: "bubble.left.and.bubble.right.fill",
        backgroundColor: Color.blue.opacity(0.1),
        iconColor: .blue
      )

      AnalyticsCard(
        title: "Outbound",
        value: analytics.outboundCount,
        icon: "arrow.up.circle.fill",
        backgroundColor: Color.green.opacity(0.1),
        iconColor: .green
      )

      AnalyticsCard(
        title: "Inbound",
        value: analytics.inboundCount,
        icon: "arrow.down.circle.fill",
        backgroundColor: Color.purple.opacity(0.1),
        iconColor: .purple
      )

      AnalyticsCard(
        title: "This Week",
        value: analytics.thisWeekCount,
        icon: "calendar.circle.fill",
        backgroundColor: Color.orange.opacity(0.1),
        iconColor: .orange
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

struct AnalyticsCard: View {
  let title: String
  let value: Int
  let icon: String
  let backgroundColor: Color
  let iconColor: Color

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: iconSize))
          .foregroundColor(iconColor)
          .accessibilityHidden(true)

        Spacer()

        Text("\(value)")
          .font(.system(size: valueSize, weight: .bold))
          .foregroundColor(.primary)
      }

      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .leading)
    .background(backgroundColor)
    .cornerRadius(12)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  // MARK: - Computed Properties

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 26 : 22
  }

  private var valueSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 32 : 28
  }

  private var cardHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 100 : 80
  }

  private var accessibilityLabel: String {
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

#Preview {
  InteractionAnalyticsCards(
    analytics: InteractionAnalytics(
      totalCount: 47,
      outboundCount: 32,
      inboundCount: 15,
      thisWeekCount: 8
    )
  )
  .padding()
  .background(Color(.systemGroupedBackground))
}
