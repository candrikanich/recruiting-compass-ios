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

      Text("Last \(trend.count) records: \(trend.type.format(trend.min)) to \(trend.type.format(trend.max)) \(trend.unit) (avg: \(trend.type.format(trend.average)))")
        .font(.caption)
        .foregroundStyle(.secondary)

      MiniBarChart(values: trend.values, maxValue: trend.max)
        .frame(height: 96)
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(trend.type.displayName) is \(trend.trend.label). \(trend.count) records, average \(trend.type.format(trend.average)) \(trend.unit)"))
  }
}
