import SwiftUI

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
    .background(Color.Surface.card)
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
