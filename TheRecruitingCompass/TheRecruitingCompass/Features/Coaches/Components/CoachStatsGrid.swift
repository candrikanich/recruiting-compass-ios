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
        color: stats.contactStatusColor,
        icon: stats.contactStatusIconName
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
  private func statCard(title: String, value: String, color: Color, icon: String? = nil) -> some View {
    VStack(spacing: 8) {
      HStack(spacing: 4) {
        if let icon {
          Image(systemName: icon)
            .font(.caption)
            .accessibilityHidden(true)
        }
        Text(value)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .font(sizeCategory.isAccessibilityCategory ? .title2.bold() : .title3.bold())
      .foregroundStyle(color)

      Text(title)
        .font(.caption.bold())
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
    .accessibilityLabel(statAccessibilityLabel(title: title, value: value))
  }

  func statAccessibilityLabel(title: String, value: String) -> String {
    String(localized: "\(title): \(value)")
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
