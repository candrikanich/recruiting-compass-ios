import SwiftUI

struct TrendCard: View {
  let trend: MetricTrend

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(trend.type.displayName)
          .font(.headline)
        Spacer()
        TrendIndicator(trend: trend.trend)
      }

      Text("Last \(trend.count) records: \(String(format: "%.2f", trend.min)) to \(String(format: "%.2f", trend.max)) \(trend.unit) (avg: \(String(format: "%.2f", trend.average)))")
        .font(.caption)
        .foregroundStyle(.secondary)

      MiniBarChart(values: trend.values, maxValue: trend.max)
        .frame(height: 96)
    }
    .padding()
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(trend.type.displayName) is \(trend.trend.label). \(trend.count) records, average \(String(format: "%.2f", trend.average)) \(trend.unit)")
  }
}
