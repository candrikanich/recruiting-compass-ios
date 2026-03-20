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

      Text("Last \(trend.count) records: \(trend.min.formatted(.number.precision(.fractionLength(2)))) to \(trend.max.formatted(.number.precision(.fractionLength(2)))) \(trend.unit) (avg: \(trend.average.formatted(.number.precision(.fractionLength(2)))))")
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
    .accessibilityLabel("\(trend.type.displayName) is \(trend.trend.label). \(trend.count) records, average \(trend.average.formatted(.number.precision(.fractionLength(2)))) \(trend.unit)")
  }
}
