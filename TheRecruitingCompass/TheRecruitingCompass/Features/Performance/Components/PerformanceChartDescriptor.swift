import SwiftUI
import Accessibility

/// VoiceOver Audio Graph for `PerformanceChartView`: lets a VoiceOver user hear the trend
/// and step through each recorded value instead of only a data-point count.
struct PerformanceChartDescriptor: AXChartDescriptorRepresentable {
  struct Point: Equatable {
    let x: Double
    let y: Double
  }

  let metrics: [PerformanceMetric]
  let metricType: MetricType?

  var points: [Point] {
    metrics
      .sorted { $0.recordedDate < $1.recordedDate }
      .map { Point(x: $0.recordedDate.timeIntervalSince1970, y: $0.value) }
  }

  func makeChartDescriptor() -> AXChartDescriptor {
    let sorted = metrics.sorted { $0.recordedDate < $1.recordedDate }
    let points = points
    // `.other` metrics can mix units under one type; only label the axis when they agree,
    // and give every point its own unit so no value is announced with the wrong one.
    let units = Set(metrics.map(\.unit))
    let axisUnit = units.count == 1 ? units.first ?? "" : ""
    let format = metricType?.format ?? { String($0) }

    let xAxis = AXNumericDataAxisDescriptor(
      title: String(localized: "Date"),
      range: Self.nonEmptyRange(points.map(\.x), padding: 86_400),
      gridlinePositions: []
    ) { Date(timeIntervalSince1970: $0).formatted(date: .abbreviated, time: .omitted) }

    let yAxis = AXNumericDataAxisDescriptor(
      title: metricType?.displayName ?? String(localized: "Value"),
      range: Self.nonEmptyRange(points.map(\.y), padding: 1),
      gridlinePositions: []
    ) { "\(format($0)) \(axisUnit)".trimmingCharacters(in: .whitespaces) }

    let series = AXDataSeriesDescriptor(
      name: metricType?.displayName ?? String(localized: "Performance"),
      isContinuous: true,
      dataPoints: zip(points, sorted).map { point, metric in
        AXDataPoint(
          x: point.x,
          y: point.y,
          label: "\(metric.metricType.format(metric.value)) \(metric.unit)".trimmingCharacters(in: .whitespaces)
        )
      }
    )

    return AXChartDescriptor(
      title: metricType?.displayName ?? String(localized: "Performance"),
      summary: nil,
      xAxis: xAxis,
      yAxis: yAxis,
      series: [series]
    )
  }

  func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
    descriptor.replaceContents(with: makeChartDescriptor())
  }

  static func nearestMetric(to date: Date, in metrics: [PerformanceMetric]) -> PerformanceMetric? {
    metrics.min {
      abs($0.recordedDate.timeIntervalSince(date)) < abs($1.recordedDate.timeIntervalSince(date))
    }
  }

  /// Audio Graphs need `lowerBound < upperBound`; a flat series would otherwise collapse to a point.
  private static func nonEmptyRange(_ values: [Double], padding: Double) -> ClosedRange<Double> {
    guard let low = values.min(), let high = values.max() else { return 0...1 }
    return low < high ? low...high : (low - padding)...(high + padding)
  }
}
