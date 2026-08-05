import SwiftUI

struct MetricRow: View {
  let metric: PerformanceMetric

  private var dateFormatted: String {
    metric.formattedDate
  }

  private var metricIcon: String {
    switch metric.metricType {
    case .velocity, .exitVelo: return "flame"
    case .sixtyTime: return "timer"
    case .popTime: return "stopwatch"
    case .battingAvg: return "baseball"
    case .era: return "chart.bar"
    case .strikeouts: return "figure.strengthtraining.traditional"
    case .other: return "chart.bar"
    }
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
