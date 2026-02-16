import SwiftUI

struct StatCardView: View {
  let card: SummaryCard

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: card.iconName)
          .font(.title3)
          .foregroundStyle(card.color)
          .accessibilityHidden(true)

        Spacer()

        if let trend = card.trend {
          trendBadge(trend)
        }
      }

      Text("\(card.value)")
        .font(.title.bold())
        .foregroundStyle(Color.darkSlate)

      Text(card.title)
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabelText)
    .accessibilityValue(card.trend ?? "")
  }

  private var accessibilityLabelText: String {
    var label = "\(card.title): \(card.value)"
    if let trend = card.trend {
      let direction = card.isPositiveTrend ? "up" : card.isNegativeTrend ? "down" : ""
      if !direction.isEmpty {
        label += ", trending \(direction), \(trend)"
      } else {
        label += ", \(trend)"
      }
    }
    return label
  }

  @ViewBuilder
  private func trendBadge(_ trend: String) -> some View {
    let isPositive = card.isPositiveTrend
    let isNegative = card.isNegativeTrend

    HStack(spacing: 2) {
      if isPositive {
        Image(systemName: "arrow.up.right")
          .font(.caption2)
      } else if isNegative {
        Image(systemName: "arrow.down.right")
          .font(.caption2)
      }
      Text(trend)
        .font(.caption2)
    }
    .foregroundStyle(isPositive ? Color.successGreen : isNegative ? Color.errorRed : Color.secondaryText)
  }
}
