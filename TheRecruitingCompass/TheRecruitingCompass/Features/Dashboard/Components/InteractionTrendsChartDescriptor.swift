import SwiftUI
import Accessibility

/// VoiceOver Audio Graph for `InteractionTrendsChart`: one bar per day, so each day's
/// count is individually navigable rather than summarized away.
struct InteractionTrendsChartDescriptor: AXChartDescriptorRepresentable {
  let trends: [InteractionTrend]

  var counts: [Int] { trends.map(\.count) }

  func makeChartDescriptor() -> AXChartDescriptor {
    let labels = trends.map { $0.calendarDay().formatted(.dateTime.month(.abbreviated).day()) }
    let total = counts.reduce(0, +)

    let xAxis = AXCategoricalDataAxisDescriptor(title: String(localized: "Day"), categoryOrder: labels)
    let yAxis = AXNumericDataAxisDescriptor(
      title: String(localized: "Interactions"),
      range: 0...Double(max(counts.max() ?? 0, 1)),
      gridlinePositions: []
    ) { String(Int($0)) }

    let series = AXDataSeriesDescriptor(
      name: String(localized: "Interactions"),
      isContinuous: false,
      dataPoints: zip(labels, counts).map { AXDataPoint(x: $0, y: Double($1)) }
    )

    return AXChartDescriptor(
      title: String(localized: "Interaction Trends"),
      summary: String(localized: "\(total) total interactions over \(trends.count) days"),
      xAxis: xAxis,
      yAxis: yAxis,
      series: [series]
    )
  }

  func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
    descriptor.replaceContents(with: makeChartDescriptor())
  }
}
