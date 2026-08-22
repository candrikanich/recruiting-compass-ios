import SwiftUI

struct MetricRow: View {
  let metric: PerformanceMetric

  private var dateFormatted: String {
    metric.formattedDate
  }

  private var metricIcon: String {
    MetricRegistry.def(for: metric.metricType.rawValue).icon
  }

  private var formattedValue: String {
    metric.formattedValue
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: metricIcon)
        .font(.title3)
        .foregroundStyle(Color.primaryGreen)
        .frame(width: 32)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(metric.displayName)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(formattedValue)
          .font(.body)
          .foregroundStyle(Color.darkSlate)

        Text(dateFormatted)
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
      }

      Spacer()
    }
    .padding(12)
    .frame(minHeight: 44)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(metric.displayName): \(formattedValue)"))
    .accessibilityValue("Recorded \(dateFormatted)")
  }
}
