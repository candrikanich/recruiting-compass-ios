import SwiftUI
import Charts

struct PerformanceChartView: View {
  let metrics: [PerformanceMetric]
  let metricType: MetricType?

  @State private var selectedDate: Date?

  private var selectedMetric: PerformanceMetric? {
    selectedDate.flatMap { PerformanceChartDescriptor.nearestMetric(to: $0, in: metrics) }
  }

  var body: some View {
    if metrics.count >= 2 {
      Chart {
        ForEach(metrics) { metric in
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
          .symbolSize(metric.id == selectedMetric?.id ? 120 : 40)
        }

        if let selectedMetric {
          RuleMark(x: .value("Date", selectedMetric.recordedDate))
            .foregroundStyle(Color.secondary.opacity(0.5))
            .annotation(
              position: .top,
              overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
            ) {
              selectionCallout(for: selectedMetric)
            }
        }
      }
      .chartXSelection(value: $selectedDate)
      .chartYScale(domain: .automatic(includesZero: false))
      .chartXAxis {
        AxisMarks(values: .automatic) { _ in
          AxisGridLine()
          AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
      }
      .frame(height: 320)
      .accessibilityLabel(String(localized: "Performance chart for \(metricType?.displayName ?? "metrics"), showing \(metrics.count) data points"))
      .accessibilityChartDescriptor(PerformanceChartDescriptor(metrics: metrics, metricType: metricType))
    } else {
      ContentUnavailableView {
        Label("Not Enough Data", systemImage: "chart.xyaxis.line")
      } description: {
        Text("Need at least 2 records to display chart")
      }
      .frame(height: 200)
    }
  }

  private func selectionCallout(for metric: PerformanceMetric) -> some View {
    VStack(spacing: 2) {
      Text("\(metric.metricType.format(metric.value)) \(metric.unit)")
        .font(.headline)
      Text(metric.recordedDate, format: .dateTime.month(.abbreviated).day().year())
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
  }
}
