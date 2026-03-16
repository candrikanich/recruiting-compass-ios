import SwiftUI

struct AtAGlanceSummary: View {
  let schoolsWithOffers: String
  let interactionsThisMonth: Int
  let daysUntilGraduation: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("At a Glance")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

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
    .clipShape(.rect(cornerRadius: 12))
    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
}

struct MetricCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(value)
        .font(.title.weight(.bold))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text(title)
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
    .accessibilityHint(metricHint)
  }

  private var metricHint: String {
    switch title {
    case "Days Until Graduation":
      return "Number of days remaining until graduation"
    case "Schools with Offers":
      return "Percentage of schools that have extended offers"
    case "Interactions This Month":
      return "Total number of interactions logged this month"
    default:
      return ""
    }
  }
}

#Preview {
  AtAGlanceSummary(
    schoolsWithOffers: "40%",
    interactionsThisMonth: 12,
    daysUntilGraduation: "365"
  )
  .padding()
}
