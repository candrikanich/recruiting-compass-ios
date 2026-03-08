import SwiftUI

struct CoachStatsGrid: View {
  let stats: CoachStats

  @Environment(\.sizeCategory) private var sizeCategory

  private var gridColumns: [GridItem] {
    [
      GridItem(.flexible(), spacing: 16),
      GridItem(.flexible(), spacing: 16),
      GridItem(.flexible(), spacing: 16)
    ]
  }

  var body: some View {
    LazyVGrid(columns: gridColumns, spacing: 16) {
      statCard(
        title: "Total Interactions",
        value: "\(stats.totalInteractions)",
        color: .accentBlue
      )

      statCard(
        title: "Days Since Contact",
        value: stats.contactStatusText,
        color: stats.contactStatusColor
      )

      statCard(
        title: "Preferred Method",
        value: stats.preferredMethod ?? "N/A",
        color: .purple
      )
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func statCard(title: String, value: String, color: Color) -> some View {
    VStack(spacing: 8) {
      Text(value)
        .font(sizeCategory.isAccessibilityCategory ? .title2.bold() : .title3.bold())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(title)
        .font(sizeCategory.isAccessibilityCategory ? .caption.bold() : .caption.bold())
        .foregroundStyle(Color.secondaryText)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.9)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .padding(.horizontal, 8)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }
}

#Preview {
  CoachStatsGrid(
    stats: CoachStats(
      totalInteractions: 12,
      daysSinceContact: 3,
      preferredMethod: "Email"
    )
  )
  .padding()
}
