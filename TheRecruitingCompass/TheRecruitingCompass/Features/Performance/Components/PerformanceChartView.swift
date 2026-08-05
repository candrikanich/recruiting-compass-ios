import SwiftUI
import Charts

struct PerformanceChartView: View {
  let metrics: [PerformanceMetric]
  let metricType: MetricType?

  var body: some View {
    if metrics.count >= 2 {
      Chart(metrics) { metric in
        LineMark(
          x: .value("Date", metric.recordedDate),
          y: .value("Value", metric.value)
        )
        .foregroundStyle(Color.accentBlue)
        .interpolationMethod(.catmullRom)

        AreaMark(
          x: .value("Date", metric.recordedDate),
          y: .value("Value", metric.value)
        )
        .foregroundStyle(
          LinearGradient(
            colors: [Color.accentBlue.opacity(0.2), Color.accentBlue.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .interpolationMethod(.catmullRom)

        PointMark(
          x: .value("Date", metric.recordedDate),
          y: .value("Value", metric.value)
        )
        .foregroundStyle(Color.accentBlue)
        .symbolSize(40)
      }
      .chartYScale(domain: .automatic(includesZero: false))
      .chartXAxis {
        AxisMarks(values: .automatic) { _ in
          AxisGridLine()
          AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
      }
      .frame(height: 320)
      .accessibilityLabel(String(localized: "Performance chart for \(metricType?.displayName ?? "metrics"), showing \(metrics.count) data points"))
    } else {
      ContentUnavailableView {
        Label("Not Enough Data", systemImage: "chart.xyaxis.line")
      } description: {
        Text("Need at least 2 records to display chart")
      }
      .frame(height: 200)
    }
  }
}
