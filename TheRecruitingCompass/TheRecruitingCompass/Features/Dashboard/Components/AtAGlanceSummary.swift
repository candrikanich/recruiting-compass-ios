import SwiftUI

struct AtAGlanceSummary: View {
  let schoolsWithOffers: String
  let avgCoachResponsiveness: String
  let avgResponsivenessColor: Color
  let interactionsThisMonth: Int
  let daysUntilGraduation: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("At a Glance")
        .font(.headline)

      Divider()

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 16) {
        MetricCard(
          title: "Schools with Offers",
          value: schoolsWithOffers,
          color: .accentBlue
        )

        MetricCard(
          title: "Avg Coach Responsiveness",
          value: avgCoachResponsiveness,
          color: avgResponsivenessColor
        )

        MetricCard(
          title: "Interactions This Month",
          value: "\(interactionsThisMonth)",
          color: .accentBlue
        )

        MetricCard(
          title: "Days Until Graduation",
          value: daysUntilGraduation,
          color: .accentBlue
        )
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct MetricCard: View {
  let title: String
  let value: String
  let color: Color

  @Environment(\.sizeCategory) var sizeCategory

  private var valueFontSize: CGFloat {
    sizeCategory >= .extraLarge ? 36 : 28
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(value)
        .font(.system(size: valueFontSize, weight: .bold))
        .foregroundColor(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text(title)
        .font(.caption)
        .foregroundColor(Color.secondaryText)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }
}

#Preview {
  AtAGlanceSummary(
    schoolsWithOffers: "40%",
    avgCoachResponsiveness: "75%",
    avgResponsivenessColor: .successGreen,
    interactionsThisMonth: 12,
    daysUntilGraduation: "365"
  )
  .padding()
}
