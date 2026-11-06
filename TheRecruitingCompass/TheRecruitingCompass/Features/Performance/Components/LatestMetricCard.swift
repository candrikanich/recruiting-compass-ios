import SwiftUI

struct LatestMetricCard: View {
  let metric: PerformanceMetric

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(metric.displayName)
        .font(.brand(.caption))
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(metric.metricType.format(metric.value))
          .font(.brand(.title))
          .bold()
          .foregroundStyle(Color.accentPrimary)

        if !metric.unit.isEmpty {
          Text(metric.unit)
            .font(.brand(.subheadline))
            .foregroundStyle(.secondary)
        }
      }

      Text(metric.formattedDate)
        .font(.brand(.caption))
        .foregroundStyle(.tertiary)

      if metric.verified {
        Label("Verified", systemImage: "checkmark.seal.fill")
          .font(.brand(.caption))
          .foregroundStyle(Color.successGreen)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color.Surface.card)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(metric.displayName), \(metric.formattedValue), recorded \(metric.formattedDate)\(metric.verified ? ", verified" : "")"))
  }
}
