import SwiftUI

/// One metric as a box in the dashboard Performance grid (mirrors web's PerformanceMetricsWidget tiles).
struct MetricTile: View {
  let metric: PerformanceMetric

  var body: some View {
    VStack(spacing: 6) {
      Text(metric.displayName)
        .font(.brand(.caption))
        .fontWeight(.medium)
        .foregroundStyle(Color.Text.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.85)

      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(metric.metricType.format(metric.value))
          .font(.brand(.title3))
          .bold()
          .foregroundStyle(Color.accentPrimary)
        if !metric.unit.isEmpty {
          Text(metric.unit)
            .font(.brand(.caption))
            .foregroundStyle(Color.Text.muted)
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.7)

      Text(metric.formattedDate)
        .font(.brand(.caption2))
        .foregroundStyle(Color.Text.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 96)
    .padding(.horizontal, 8)
    .padding(.vertical, 12)
    .background(Color.Surface.background)
    .clipShape(.rect(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.Surface.border, lineWidth: 1))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(metric.displayName): \(metric.formattedValue)"))
    .accessibilityValue("Recorded \(metric.formattedDate)")
  }
}
