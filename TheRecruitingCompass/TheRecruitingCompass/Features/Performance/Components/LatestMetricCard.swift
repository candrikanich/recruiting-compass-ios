import SwiftUI

struct LatestMetricCard: View {
  let metric: PerformanceMetric

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(metric.displayName)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(String(format: "%.2f", metric.value))
          .font(.title)
          .fontWeight(.bold)
          .foregroundStyle(Color.accentBlue)

        if !metric.unit.isEmpty {
          Text(metric.unit)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Text(metric.formattedDate)
        .font(.caption2)
        .foregroundStyle(.tertiary)

      if metric.verified {
        Label("Verified", systemImage: "checkmark.seal.fill")
          .font(.caption2)
          .foregroundStyle(Color.successGreen)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(metric.displayName), \(metric.formattedValue), recorded \(metric.formattedDate)\(metric.verified ? ", verified" : "")")
  }
}
